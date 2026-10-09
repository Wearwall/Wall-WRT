package athenaLed

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// GPIO bases vary between kernels; the board's TLMM offsets do not.
var gpioSysfsRoot = "/sys/class/gpio"

func getGpioPin() (int, int, int, int, error) {
	chips, err := filepath.Glob(filepath.Join(gpioSysfsRoot, "gpiochip*"))
	if err != nil {
		return 0, 0, 0, 0, err
	}
	base := -1
	for _, chip := range chips {
		label, err := os.ReadFile(filepath.Join(chip, "label"))
		if err != nil {
			continue
		}
		if !strings.Contains(string(label), "1000000.pinctrl") && !strings.Contains(string(label), "ipq6018") {
			continue
		}
		rawBase, err := os.ReadFile(filepath.Join(chip, "base"))
		if err != nil {
			return 0, 0, 0, 0, err
		}
		rawCount, err := os.ReadFile(filepath.Join(chip, "ngpio"))
		if err != nil {
			return 0, 0, 0, 0, err
		}
		candidate, err := strconv.Atoi(strings.TrimSpace(string(rawBase)))
		if err != nil || candidate < 0 {
			return 0, 0, 0, 0, fmt.Errorf("invalid GPIO base")
		}
		count, err := strconv.Atoi(strings.TrimSpace(string(rawCount)))
		if err != nil || count <= 74 {
			return 0, 0, 0, 0, fmt.Errorf("invalid TLMM GPIO count")
		}
		if base >= 0 {
			return 0, 0, 0, 0, fmt.Errorf("ambiguous TLMM controller")
		}
		base = candidate
	}
	if base < 0 {
		return 0, 0, 0, 0, fmt.Errorf("Athena TLMM GPIO sysfs controller not found")
	}
	return base + 69, base + 70, base + 73, base + 74, nil
}
