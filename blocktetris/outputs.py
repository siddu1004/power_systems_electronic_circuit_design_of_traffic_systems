"""Never overwrite an earlier result: if a file exists, write name_2.ext, name_3.ext, ...

Every experiment script writes through `keep(path)`, so each run adds to the
record instead of replacing it (earlier versions stay comparable)."""
import os


def keep(path):
    if not os.path.exists(path):
        return path
    root, ext = os.path.splitext(path)
    k = 2
    while os.path.exists(f"{root}_{k}{ext}"):
        k += 1
    return f"{root}_{k}{ext}"
