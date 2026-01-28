module polynomial_differentiator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] coeff [0:15],
    output reg [11:0] result [0:15],
    output reg done,
    output reg [3:0] result_len
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    reg [3:0] current_index;
    reg [11:0] temp_result;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            cycle_count <= 8'd0;
            current_index <= 4'd0;
            temp_result <= 12'd0;
            
            // Initialize result array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 12'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_len <= 4'd0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= COMPUTE;
                        current_index <= 4'd1;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute result[current_index-1] = coeff[current_index] * current_index
                    temp_result <= $signed(coeff[current_index]) * $signed(current_index);
                    result[current_index - 1] <= temp_result;
                    
                    // Move to next coefficient
                    current_index <= current_index + 4'd1;
                    
                    // Check if done with computation
                    if (current_index >= len || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result_len <= len - 4'd1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule