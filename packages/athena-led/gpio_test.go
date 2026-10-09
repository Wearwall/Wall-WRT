package athenaLed

import (
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

func TestGPIOBase(t *testing.T) {
	previous := gpioSysfsRoot
	defer func() { gpioSysfsRoot = previous }()
	for _, base := range []int{432, 512, 600} {
		gpioSysfsRoot = t.TempDir()
		chip := filepath.Join(gpioSysfsRoot, "gpiochip"+strconv.Itoa(base))
		if err := os.Mkdir(chip, 0755); err != nil {
			t.Fatal(err)
		}
		for name, content := range map[string]string{"label": "1000000.pinctrl", "base": strconv.Itoa(base), "ngpio": "80"} {
			if err := os.WriteFile(filepath.Join(chip, name), []byte(content), 0644); err != nil {
				t.Fatal(err)
			}
		}
		a, b, c, d, err := getGpioPin()
		if err != nil || a != base+69 || b != base+70 || c != base+73 || d != base+74 {
			t.Fatalf("wrong GPIO mapping for base %d: %d %d %d %d %v", base, a, b, c, d, err)
		}
	}
	gpioSysfsRoot = t.TempDir()
	if _, _, _, _, err := getGpioPin(); err == nil {
		t.Fatal("missing TLMM controller accepted")
	}
}
