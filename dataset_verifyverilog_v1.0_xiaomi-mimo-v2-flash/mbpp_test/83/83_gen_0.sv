module compute_char_from_sum_mod26 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    output reg [3:0] idx_out,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] FETCH = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] idx;  // Index counter 0-15
    reg [31:0] sum; // Accumulator for sum of character positions
    reg [31:0] temp_result;
    reg done_flag;

    // ASCII constant
    localparam [7:0] ASCII_A = 8'd97;

    // Combinational logic for next state and outputs
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FETCH;
                end else begin
                    next_state = IDLE;
                end
            end
            FETCH: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                if (idx == 4'd15) begin
                    next_state = FINISH;
                end else begin
                    next_state = FETCH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            sum <= 32'd0;
            temp_result <= 32'd0;
            result <= 8'd0;
            done <= 1'b0;
            done_flag <= 1'b0;
            idx_out <= 4'd0;
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    idx <= 4'd0;
                    sum <= 32'd0;
                    temp_result <= 32'd0;
                    done_flag <= 1'b0;
                    // Generate first index if starting
                    idx_out <= 4'd0;
                    if (start) begin
                        state <= FETCH;
                    end else begin
                        state <= IDLE;
                    end
                end

                FETCH: begin
                    state <= COMPUTE;
                    // idx_out is already set from previous cycle or IDLE
                    // During this cycle, external memory provides char_in
                end

                COMPUTE: begin
                    // Calculate (char_in - 'a' + 1)
                    // Check if char_in is valid (between 'a' and 'z')
                    // Assuming valid input for this problem
                    sum <= sum + (char_in - ASCII_A + 8'd1);
                    
                    // Increment index for next iteration
                    if (idx < 4'd15) begin
                        idx <= idx + 4'd1;
                        idx_out <= idx + 4'd1; // Prepare next index
                    end
                    
                    state <= next_state;
                end

                FINISH: begin
                    // Calculate sum_mod_26 = sum % 26
                    // 26 = 0x1A
                    temp_result <= sum % 32'd26;
                    
                    // Determine result ASCII
                    // If mod == 0, result is 'z' (122)
                    // Else result is 'a' + mod - 1
                    if ((sum % 32'd26) == 32'd0) begin
                        result <= 8'd122; // 'z'
                    end else begin
                        result <= ASCII_A + (sum % 32'd26) - 32'd1;
                    end
                    
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule