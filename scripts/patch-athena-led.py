#!/usr/bin/env python3
"""Replace upstream's distribution-dependent GPIO numbers with chip offsets."""
from pathlib import Path
import sys

path = Path(sys.argv[1]) / 'internal/ledScreen.go'
source = path.read_text()
start = source.index('func getGpioPin()')
end = source.index('func (screen LedScreen) Destroy()', start)
source = source[:start] + source[end:]
source = source.replace('\t"bufio"\n', '')
path.write_text(source)
