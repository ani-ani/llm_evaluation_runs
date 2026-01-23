module mirror_check (
    input clk,
    input rst_n, // active low
    input start,
    input [15:0] char_valid,
    input [7:0] char_data [15:0],
    input [4:0] str_length,
    output reg is_mirror,
    output reg done
);

// Wires for next pointers
wire [3:0] left_next, right_next;

// Registers
reg [2:0] state; // IDLE=0, PROCESSING=1, DONE=2
reg [3:0] left, right;
reg is_mirror_reg;
reg done_reg;

// Local parameters for states
localparam IDLE = 0;
localparam PROCESSING = 1;
localparam DONE = 2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        left <= 0;
        right <= 0;
        is_mirror_reg <= 0;
        done_reg <= 0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    if (str_length == 0) begin
                        state <= DONE;
                        is_mirror_reg <= 1;
                        done_reg <= 1;
                    end else begin
                        left <= 0;
                        right <= str_length - 1;
                        state <= PROCESSING;
                    end
                end else begin
                    state <= IDLE;
                end
            end
            PROCESSING: begin
                // Check current characters
                if (char_valid[left] && char_valid[right] && (char_data[left] == char_data[right])) begin
                    // Current check passed, compute next pointers
                    left_next = left + 1;
                    right_next = right - 1;
                    if (left_next > (signed)right_next) begin
                        // All checks passed, success
                        is_mirror_reg <= 1;
                        state <= DONE;
                        done_reg <= 1;
                    end else begin
                        // Continue processing
                        left <= left_next;
                        right <= right_next;
                        state <= PROCESSING;
                    end
                end else begin
                    // Check failed
                    is_mirror_reg <= 0;
                    state <= DONE;
                    done_reg <= 1;
                end
            end
            DONE: begin
                state <= DONE;
            end
        endcase
    end

// Assign outputs
assign is_mirror = is_mirror_reg;
assign done = done_reg;

endmodule