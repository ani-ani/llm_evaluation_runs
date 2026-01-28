module pow_array (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] exponents,
    input wire [7:0] nums [0:9],
    input wire [9:0] valid_in,
    output reg [15:0] results [0:9],
    output reg [9:0] valid_out,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] index;  // 0-9 for 10 elements
    reg [7:0] nums_reg [0:9];  // Store input numbers
    reg [9:0] valid_reg;  // Store valid mask
    reg [1:0] exponents_reg;  // Store exponent selector
    reg [15:0] temp_result;  // Temporary result for current element
    reg [9:0] valid_out_next;
    reg done_next;
    
    // Combinatorial computation signals
    wire [31:0] x_squared;
    wire [31:0] x_cubed;
    wire [31:0] x_fifth;
    wire [31:0] x_fourth;
    wire [31:0] temp_32;
    wire [15:0] saturated_result;
    
    // Compute x^2
    assign x_squared = {24'd0, nums_reg[index]} * {24'd0, nums_reg[index]};
    
    // Compute x^3
    assign x_cubed = x_squared * {24'd0, nums_reg[index]};
    
    // Compute x^4 for x^5
    assign x_fourth = x_squared * x_squared;
    
    // Compute x^5
    assign x_fifth = x_fourth * {24'd0, nums_reg[index]};
    
    // Select result based on exponent
    assign temp_32 = (exponents_reg == 2'd0) ? x_squared :
                     (exponents_reg == 2'd1) ? x_cubed :
                     x_fifth;
    
    // Saturate to 16 bits
    assign saturated_result = (temp_32 > 32'd65535) ? 16'd65535 : temp_32[15:0];
    
    integer i;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            // Synchronous reset
            state <= IDLE;
            index <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 10; i = i + 1) begin
                results[i] <= 16'd0;
                nums_reg[i] <= 8'd0;
            end
            valid_reg <= 10'd0;
            valid_out <= 10'd0;
            exponents_reg <= 2'd0;
            temp_result <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_out <= 10'd0;
                    if (start) begin
                        state <= COMPUTE;
                        index <= 4'd0;
                        valid_reg <= valid_in;
                        exponents_reg <= exponents;
                        // Store input numbers
                        for (i = 0; i < 10; i = i + 1) begin
                            nums_reg[i] <= nums[i];
                        end
                    end
                end
                
                COMPUTE: begin
                    // Compute power for current element
                    if (valid_reg[index]) begin
                        temp_result <= saturated_result;
                    end else begin
                        temp_result <= 16'd0;
                    end
                    
                    // Move to next element or finish
                    if (index == 4'd9) begin
                        state <= DONE;
                        index <= 4'd0;
                    end else begin
                        index <= index + 4'd1;
                    end
                end
                
                DONE: begin
                    // Store result for previous element (index-1)
                    if (index < 4'd10) begin
                        results[index] <= temp_result;
                        valid_out[index] <= valid_reg[index];
                        index <= index + 4'd1;
                    end
                    
                    // When all results stored, set done
                    if (index == 4'd9) begin
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule