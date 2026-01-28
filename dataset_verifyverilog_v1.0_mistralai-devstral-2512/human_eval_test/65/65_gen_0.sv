module circular_shift(
    input clk,
    input rst_n,
    input start,
    input [15:0] x,
    input [3:0] shift,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] EXTRACT = 3'd1;
    localparam [2:0] SHIFT_D = 3'd2;
    localparam [2:0] RECON   = 3'd3;
    localparam [2:0] FINISH  = 3'd4;

    reg [2:0] state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;

    // Digit storage (4 digits, 4-bit each)
    reg [3:0] digits [0:3];
    reg [3:0] shifted_digits [0:3];

    // Extract digits from x
    always @(*) begin
        digits[0] = x[3:0];      // d0: units
        digits[1] = x[7:4];      // d1: tens
        digits[2] = x[11:8];     // d2: hundreds
        digits[3] = x[15:12];    // d3: thousands
    end

    // Compute effective shift
    wire [1:0] effective_shift = shift[1:0];

    // Shift digits
    always @(*) begin
        case (effective_shift)
            2'd0: begin
                shifted_digits[0] = digits[0];
                shifted_digits[1] = digits[1];
                shifted_digits[2] = digits[2];
                shifted_digits[3] = digits[3];
            end
            2'd1: begin
                shifted_digits[0] = digits[3];
                shifted_digits[1] = digits[0];
                shifted_digits[2] = digits[1];
                shifted_digits[3] = digits[2];
            end
            2'd2: begin
                shifted_digits[0] = digits[2];
                shifted_digits[1] = digits[3];
                shifted_digits[2] = digits[0];
                shifted_digits[3] = digits[1];
            end
            2'd3: begin
                shifted_digits[0] = digits[1];
                shifted_digits[1] = digits[2];
                shifted_digits[2] = digits[3];
                shifted_digits[3] = digits[0];
            end
            default: begin
                shifted_digits[0] = digits[0];
                shifted_digits[1] = digits[1];
                shifted_digits[2] = digits[2];
                shifted_digits[3] = digits[3];
            end
        endcase
    end

    // Reconstruct result from shifted digits
    always @(*) begin
        result = {shifted_digits[3], shifted_digits[2], shifted_digits[1], shifted_digits[0]};
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= EXTRACT;
                    end
                end

                EXTRACT: begin
                    cycle_count <= cycle_count + 4'd1;
                    state <= SHIFT_D;
                end

                SHIFT_D: begin
                    cycle_count <= cycle_count + 4'd1;
                    state <= RECON;
                end

                RECON: begin
                    cycle_count <= cycle_count + 4'd1;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule