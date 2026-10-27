"""Чтение и запись файлов Aseprite (.aseprite / .ase) без самого Aseprite.

Формат: https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md
Пишется подмножество: RGBA, слои (обычные и опорные), ячейки, метки анимаций,
палитра, текст пользователя у ячеек. Читается шире: RGBA и индексированный режим,
группы слоёв, связанные ячейки, текст пользователя.
"""

import struct
import zlib

from PIL import Image

LAYER_VISIBLE = 1
LAYER_EDITABLE = 2
LAYER_REFERENCE = 64


class Layer:
    def __init__(self, name, flags=LAYER_VISIBLE | LAYER_EDITABLE, level=0, group=False, opacity=255):
        self.name = name
        self.flags = flags
        self.level = level  # вложенность в группы
        self.group = group
        self.opacity = opacity
        self.path = name  # «группа/слой» — заполняет чтение

    @property
    def visible(self):
        return bool(self.flags & LAYER_VISIBLE)

    @property
    def reference(self):
        return bool(self.flags & LAYER_REFERENCE)


class Tag:
    def __init__(self, name, start, end):
        self.name = name
        self.start = start
        self.end = end


class Sprite:
    """Спрайт: размер, слои (снизу вверх), кадры. Кадр — {"duration": мс,
    "cels": {номер_слоя: (x, y, Image RGBA)}, "data": {номер_слоя: текст}}."""

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.layers = []
        self.frames = []
        self.tags = []
        self.palette = []  # [(r, g, b, a)]

    def layer_index(self, name):
        for i, layer in enumerate(self.layers):
            if layer.name == name or layer.path == name:
                return i
        return -1

    def image(self, frame, layer):
        """Картинка слоя в кадре размером с холст (прозрачная, если ячейки нет)."""
        out = Image.new("RGBA", (self.width, self.height), (0, 0, 0, 0))
        cel = self.frames[frame]["cels"].get(layer)
        if cel is not None:
            x, y, img = cel
            out.paste(img, (x, y), img)
        return out


# ------------------------------------------------------------ запись
def _string(s):
    b = s.encode("utf-8")
    return struct.pack("<H", len(b)) + b


def _chunk(kind, data):
    return struct.pack("<IH", len(data) + 6, kind) + data


def write(sprite, path):
    frames = []
    for n, frame in enumerate(sprite.frames):
        chunks = []
        if n == 0:
            if sprite.palette:
                pal = struct.pack("<III8x", len(sprite.palette), 0, len(sprite.palette) - 1)
                for r, g, b, a in sprite.palette:
                    pal += struct.pack("<H4B", 0, r, g, b, a)
                chunks.append(_chunk(0x2019, pal))
            for layer in sprite.layers:
                data = struct.pack("<HHHHHHB3x", layer.flags, 1 if layer.group else 0, layer.level, 0, 0, 0,
                                   layer.opacity)
                chunks.append(_chunk(0x2004, data + _string(layer.name)))
            if sprite.tags:
                tags = struct.pack("<H8x", len(sprite.tags))
                for t in sprite.tags:
                    tags += struct.pack("<HHBH6x3Bx", t.start, t.end, 0, 0, 0, 0, 0) + _string(t.name)
                chunks.append(_chunk(0x2018, tags))
        for li in sorted(frame["cels"]):
            x, y, img = frame["cels"][li]
            img = img.convert("RGBA")
            head = struct.pack("<HhhBHh5x", li, x, y, 255, 2, 0)
            body = struct.pack("<HH", img.width, img.height) + zlib.compress(img.tobytes())
            chunks.append(_chunk(0x2005, head + body))
            text = frame.get("data", {}).get(li)
            if text:
                chunks.append(_chunk(0x2020, struct.pack("<I", 1) + _string(text)))
        body = b"".join(chunks)
        head = struct.pack("<IHHH2xI", 16 + len(body), 0xF1FA, min(len(chunks), 0xFFFF),
                           frame.get("duration", 100), len(chunks))
        frames.append(head + body)
    body = b"".join(frames)
    header = struct.pack("<IHHHHHIH8xB3xHBBhhHH84x", 128 + len(body), 0xA5E0, len(sprite.frames),
                         sprite.width, sprite.height, 32, 1, 100, 0, len(sprite.palette) or 256, 1, 1,
                         0, 0, 16, 16)
    assert len(header) == 128
    with open(path, "wb") as f:
        f.write(header + body)


# ------------------------------------------------------------ чтение
class _Reader:
    def __init__(self, data, pos=0):
        self.data = data
        self.pos = pos

    def take(self, fmt):
        vals = struct.unpack_from("<" + fmt, self.data, self.pos)
        self.pos += struct.calcsize("<" + fmt)
        return vals if len(vals) > 1 else vals[0]

    def string(self):
        n = self.take("H")
        s = self.data[self.pos:self.pos + n].decode("utf-8")
        self.pos += n
        return s


def read(path):
    with open(path, "rb") as f:
        data = f.read()
    r = _Reader(data)
    _, magic, nframes, width, height, depth = r.take("IHHHHH")
    if magic != 0xA5E0:
        raise ValueError(f"{path}: не файл Aseprite")
    if depth not in (32, 8):
        raise ValueError(f"{path}: режим цвета {depth} бит не поддерживается (нужен RGBA или индексированный)")
    r.pos = 28
    transparent = r.take("B")
    sprite = Sprite(width, height)
    palette = {}
    pos = 128
    stack = []  # имена групп по уровням
    for n in range(nframes):
        fr = _Reader(data, pos)
        size, fmagic, old_chunks, duration, _, new_chunks = fr.take("IHHHHI")
        if fmagic != 0xF1FA:
            raise ValueError(f"{path}: испорчен кадр {n}")
        count = new_chunks or old_chunks
        frame = {"duration": duration, "cels": {}, "data": {}}
        last_cel = None
        for _ in range(count):
            start = fr.pos
            csize, kind = fr.take("IH")
            body = _Reader(data, fr.pos)
            if kind == 0x2004:
                flags, ltype, level, _, _, _, opacity = body.take("HHHHHHB")
                body.pos += 3
                name = body.string()
                layer = Layer(name, flags, level, ltype == 1, opacity)
                del stack[level:]
                layer.path = "/".join(stack + [name])
                stack.append(name)
                sprite.layers.append(layer)
                last_cel = None
            elif kind == 0x2005:
                li, x, y, opacity, ctype = body.take("HhhBH")
                body.pos += 7
                if ctype in (0, 2):
                    w, h = body.take("HH")
                    raw = data[body.pos:start + csize]
                    if ctype == 2:
                        raw = zlib.decompress(raw)
                    img = _image(raw, w, h, depth, palette, transparent, sprite.layers[li])
                    frame["cels"][li] = (x, y, img)
                elif ctype == 1:
                    link = body.take("H")
                    frame["cels"][li] = sprite.frames[link]["cels"][li]
                last_cel = li
            elif kind == 0x2018:
                ntags = body.take("H")
                body.pos += 8
                for _ in range(ntags):
                    start_f, end_f = body.take("HH")
                    body.pos += 1 + 2 + 6 + 3 + 1
                    sprite.tags.append(Tag(body.string(), start_f, end_f))
            elif kind == 0x2019:
                total, first, last = body.take("III")
                body.pos += 8
                for i in range(first, last + 1):
                    flags, cr, cg, cb, ca = body.take("H4B")
                    if flags & 1:
                        body.string()
                    palette[i] = (cr, cg, cb, ca)
                sprite.palette = [palette.get(i, (0, 0, 0, 0)) for i in range(total)]
            elif kind in (0x0004, 0x0011) and not palette:
                packets = body.take("H")
                i = 0
                for _ in range(packets):
                    skip, ncolors = body.take("BB")
                    i += skip
                    for _ in range(ncolors or 256):
                        cr, cg, cb = body.take("BBB")
                        if kind == 0x0011:
                            cr, cg, cb = cr * 255 // 63, cg * 255 // 63, cb * 255 // 63
                        palette[i] = (cr, cg, cb, 255)
                        i += 1
            elif kind == 0x2020 and last_cel is not None:
                flags = body.take("I")
                if flags & 1:
                    frame["data"][last_cel] = body.string()
            fr.pos = start + csize
        sprite.frames.append(frame)
        pos += size
    return sprite


def _image(raw, w, h, depth, palette, transparent, layer):
    if depth == 32:
        return Image.frombytes("RGBA", (w, h), raw)
    img = Image.new("RGBA", (w, h))
    px = []
    background = bool(layer.flags & 8)
    for idx in raw[:w * h]:
        if idx == transparent and not background:
            px.append((0, 0, 0, 0))
        else:
            px.append(palette.get(idx, (0, 0, 0, 255)))
    img.putdata(px)
    return img
