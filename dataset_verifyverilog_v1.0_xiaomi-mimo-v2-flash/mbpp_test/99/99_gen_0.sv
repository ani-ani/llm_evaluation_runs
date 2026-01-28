module BinaryConverter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg [15:0] result,
    output reg [3:0] len,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] CHECK_BIT  = 3'd2;
    localparam [2:0] APPEND     = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] bit_index;          // Current bit position (15 down to 0)
    reg [3:0] current_len;        // Length being built
    reg [15:0] current_result;    // Result being built
    reg [15:0] temp_n;            // Working copy of n
    reg started;                  // Flag to indicate if we've started appending
    reg [7:0] cycle_count;        // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            len <= 4'd0;
            done <= 1'b0;
            bit_index <= 4'd0;
            current_len <= 4'd0;
            current_result <= 16'd0;
            temp_n <= 16'd0;
            started <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    bit_index <= 4'd15;
                    current_len <= 4'd0;
                    current_result <= 16'd0;
                    started <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    temp_n <= n;
                    state <= CHECK_BIT;
                end

                CHECK_BIT: begin
                    // Check if current bit is 1
                    if (temp_n[bit_index]) begin
                        started <= 1'b1;
                        state <= APPEND;
                    end else if (started) begin
                        // Not a leading zero, append '0'
                        state <= APPEND;
                    end else begin
                        // Leading zero, skip
                        if (bit_index == 4'd0) begin
                            state <= FINISH;
                        end else begin
                            bit_index <= bit_index - 4'd1;
                            cycle_count <= cycle_count + 8'd1;
                        end
                    end
                end

                APPEND: begin
                    // Append '1' if bit is 1, else '0'
                    if (temp_n[bit_index]) begin
                        current_result <= {current_result[14:0], 1'b1};
                    end else begin
                        current_result <= {current_result[14:0], 1'b0};
                    end
                    current_len <= current_len + 4'd1;
                    
                    // Move to next bit
                    if (bit_index == 4'd0) begin
                        state <= FINISH;
                    end else begin
                        bit_index <= bit_index - 4'd1;
                        state <= CHECK_BIT;
                        cycle_count <= cycle_count + 8'd1;
                    end
                end

                FINISH: begin
                    result <= current_result;
                    len <= current_len;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Safety timeout
            if (state != IDLE && state != FINISH) begin
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISH;
                end
            end
        end
    end

endmodule