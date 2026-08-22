# ============================================================
# tiny-tpu formal verification Makefile
# ============================================================
# Usage:
#   make check-pe       # Can Yosys parse it?
#   make pe             # PE: bmc + prove + cover + anyconst
#   make pe-bmc         # BMC only (fast debug loop)
#   make decoder        # decoder: bmc + prove + cover
#   make clean
# ============================================================

SRC_DIR   := ../src
BUILD_DIR := ../build

SBY := sby -f

.PHONY: all pe decoder clean check-pe check-decoder dump-pe dump-decoder

all: pe decoder

# ------------------------------------------------------------
# Parse checks — RUN THESE BEFORE ANYTHING ELSE
# ------------------------------------------------------------
check-pe:
	@echo "=== pe.sv parse check ==="
	yosys -p "read_verilog -sv -formal $(SRC_DIR)/pe.sv; hierarchy -top pe; stat"

check-decoder:
	@echo "=== decoder.sv parse check ==="
	yosys -p "read_verilog -sv -formal $(SRC_DIR)/decoder.sv; hierarchy -top decoder; stat"

# Dump elaborated RTL to find the real internal register names
# (useful when deciding what to reference from the wrapper)
dump-pe:
	@mkdir -p $(BUILD_DIR)
	yosys -p "read_verilog -sv -formal $(SRC_DIR)/pe.sv; hierarchy -top pe; proc; \
	          write_verilog -noattr $(BUILD_DIR)/pe_elab.v"
	@echo "--> check $(BUILD_DIR)/pe_elab.v for the actual register names"

dump-decoder:
	@mkdir -p $(BUILD_DIR)
	yosys -p "read_verilog -sv -formal $(SRC_DIR)/decoder.sv; hierarchy -top decoder; proc; \
	          write_verilog -noattr $(BUILD_DIR)/decoder_elab.v"
	@echo "--> check $(BUILD_DIR)/decoder_elab.v for the actual register names"

# ------------------------------------------------------------
# PE
# ------------------------------------------------------------
pe:
	cd pe && $(SBY) pe.sby

pe-bmc:
	cd pe && $(SBY) pe.sby bmc

pe-prove:
	cd pe && $(SBY) pe.sby prove

pe-cover:
	cd pe && $(SBY) pe.sby cvr

pe-anyconst:
	cd pe && $(SBY) pe.sby anyconst

# ------------------------------------------------------------
# Decoder
# ------------------------------------------------------------
decoder:
	cd decoder && $(SBY) decoder.sby

decoder-bmc:
	cd decoder && $(SBY) decoder.sby bmc

decoder-prove:
	cd decoder && $(SBY) decoder.sby prove

decoder-cover:
	cd decoder && $(SBY) decoder.sby cvr

# ------------------------------------------------------------
# Waveform viewing
# ------------------------------------------------------------
wave-pe:
	gtkwave pe/pe_bmc/engine_0/trace.vcd &

wave-decoder:
	gtkwave decoder/decoder_bmc/engine_0/trace.vcd &

# ------------------------------------------------------------
clean:
	rm -rf pe/pe_* decoder/decoder_* $(BUILD_DIR)