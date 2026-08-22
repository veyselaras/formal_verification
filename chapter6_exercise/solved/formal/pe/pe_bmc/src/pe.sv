`default_nettype none
`timescale 1ns/1ns

// PROCESSING ELEMENT (PE)
// > Fundamental compute unit in the systolic array
// > Weight-stationary dataflow: weight loaded once, held during computation
// > Performs INT8 multiply-accumulate with 32-bit accumulator
// > Data flows west->east, partial sums flow north->south
//
// Operation modes:
// 1. Weight loading: when weight_load=1, data_in_west is stored as weight
// 2. Compute: multiply activation by weight, add to partial sum from north
// 3. Pass-through: forward activation east, forward partial sum south
//
// Timing:
// - 1 cycle latency for data propagation (pipelined)
// - Weight remains stationary until next weight_load

module pe #(
    parameter DATA_WIDTH = 8,           // INT8 operands
    parameter ACC_WIDTH = 32            // 32-bit accumulator for overflow prevention
) (
    input wire clk,
    input wire reset,
    input wire enable,                  // PE active for current computation

    // Control signals
    input wire weight_load,             // Load new weight from west input
    input wire clear_acc,               // Clear accumulator for new output tile

    // Data inputs
    input wire signed [DATA_WIDTH-1:0] data_in_west,    // Activation from west neighbor (or weight during load)
    input wire signed [ACC_WIDTH-1:0] psum_in_north,    // Partial sum from north neighbor

    // Data outputs
    output reg signed [DATA_WIDTH-1:0] data_out_east,   // Activation forwarded to east neighbor
    output reg signed [ACC_WIDTH-1:0] psum_out_south,   // Partial sum to south neighbor

    // Debug outputs
    output wire signed [DATA_WIDTH-1:0] weight_debug,   // Current weight value (for verification)
    output wire signed [ACC_WIDTH-1:0] acc_debug        // Current accumulator value
);

    // Internal registers
    reg signed [DATA_WIDTH-1:0] weight_reg;             // Stationary weight register
    reg signed [ACC_WIDTH-1:0] accumulator;             // Local accumulator (optional, for output-stationary mode)

    // Intermediate multiply result (needs wider width to prevent overflow)
    // INT8 x INT8 = 16 bits max
    wire signed [2*DATA_WIDTH-1:0] mult_result;
    assign mult_result = data_in_west * weight_reg;

    // Debug outputs
    assign weight_debug = weight_reg;
    assign acc_debug = accumulator;

    always @(posedge clk) begin
        if (reset) begin
            weight_reg <= {DATA_WIDTH{1'b0}};
            accumulator <= {ACC_WIDTH{1'b0}};
            data_out_east <= {DATA_WIDTH{1'b0}};
            psum_out_south <= {ACC_WIDTH{1'b0}};
        end else if (enable) begin
            // Weight loading phase
            if (weight_load) begin
                weight_reg <= data_in_west;
                // During weight load, don't compute - just pass zeros
                data_out_east <= {DATA_WIDTH{1'b0}};
                psum_out_south <= psum_in_north;
            end else begin
                // Normal compute phase

                // Forward activation to east neighbor (1 cycle delay for systolic flow)
                data_out_east <= data_in_west;

                // MAC operation: psum_out = psum_in + (activation * weight)
                // Sign extension happens automatically with signed types
                psum_out_south <= psum_in_north + mult_result;

                // Update local accumulator (for output-stationary mode or debugging)
                if (clear_acc) begin
                    accumulator <= mult_result;
                end else begin
                    accumulator <= accumulator + mult_result;
                end
            end
        end else begin
            // When disabled, hold outputs stable
            data_out_east <= data_out_east;
            psum_out_south <= psum_out_south;
        end
    end

endmodule
