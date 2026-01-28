module ExtractNegatives (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr_i [0:7],
    input wire [3:0] len_i,
    output reg signed [7:0] arr_o [0:7],
    output reg [3:0] len_o,
    output reg done
);

    // State machine definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] STORE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] scan_idx;          // Current index in input array (0-15)
    reg [3:0] write_idx;         // Current index in output array (0-15)
    reg [3:0] cycle_count;       // Prevent infinite loops
    reg signed [7:0] current_val; // Store current element being checked
    wire is_negative;             // MSB check for negative number

    // Constant for max cycles
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Combinational logic for negative check
    assign is_negative = current_val[7];

    // Initialize array outputs in reset
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                arr_o[i] <= 8'sd0;
            end
        end
    end

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scan_idx <= 4'd0;
            write_idx <= 4'd0;
            len_o <= 4'd0;
            current_val <= 8'sd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    scan_idx <= 4'd0;
                    write_idx <= 4'd0;
                    len_o <= 4'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (len_i == 4'd0) begin
                            state <= DONE_STATE;
                        end else begin
                            current_val <= arr_i[0];
                            state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    if (is_negative) begin
                        state <= STORE;
                    end else begin
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    scan_idx <= scan_idx + 4'd1;
                    cycle_count <= cycle_count + 8'd1;
                    if (scan_idx + 4'd1 >= len_i || cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        current_val <= arr_i[scan_idx + 4'd1];
                        state <= CHECK;
                    end
                end

                STORE: begin
                    if (write_idx < 4'd8) begin
                        arr_o[write_idx] <= current_val;
                        write_idx <= write_idx + 4'd1;
                        len_o <= len_o + 4'd1;
                    end
                    scan_idx <= scan_idx + 4'd1;
                    cycle_count <= cycle_count + 8'd1;
                    if (scan_idx + 4'd1 >= len_i || cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        current_val <= arr_i[scan_idx + 4'd1];
                        state <= CHECK;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule