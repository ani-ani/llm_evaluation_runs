module compute_sum_product (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [15:0] sum_out,
    output reg [15:0] prod_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] sum_reg;
    reg [15:0] prod_reg;
    reg [3:0] counter;
    reg [15:0] current_element;
    reg [31:0] temp_product;
    reg overflow_flag;
    
    // Flop for current element from array
    integer i;
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                if (counter >= len || len == 4'd0)
                    next_state = DONE_STATE;
                else
                    next_state = COMPUTE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum_reg <= 16'd0;
            prod_reg <= 16'd0;
            counter <= 4'd0;
            done <= 1'b0;
            sum_out <= 16'd0;
            prod_out <= 16'd0;
            overflow_flag <= 1'b0;
            temp_product <= 32'd0;
            current_element <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    overflow_flag <= 1'b0;
                    
                    if (start) begin
                        // Initialize for new computation
                        if (len == 4'd0) begin
                            sum_reg <= 16'd0;
                            prod_reg <= 16'd1;
                        end else begin
                            // Get first element
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i == 0)
                                    current_element <= {8'd0, arr[0]};
                            end
                            sum_reg <= {8'd0, arr[0]};
                            prod_reg <= {8'd0, arr[0]};
                            counter <= 4'd1;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (counter < len) begin
                        // Get current element
                        current_element <= {8'd0, arr[counter]};
                        
                        // Update sum
                        sum_reg <= sum_reg + {8'd0, arr[counter]};
                        
                        // Update product with overflow detection
                        temp_product <= prod_reg * {8'd0, arr[counter]};
                        
                        // Check for overflow (result > 16 bits)
                        if (temp_product[31:16] != 16'd0) begin
                            overflow_flag <= 1'b1;
                        end
                        
                        counter <= counter + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    // Finalize outputs
                    sum_out <= sum_reg;
                    
                    if (overflow_flag || len == 4'd0) begin
                        prod_out <= 16'd1;
                    end else begin
                        prod_out <= prod_reg;
                    end
                    
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    sum_reg <= 16'd0;
                    prod_reg <= 16'd0;
                    counter <= 4'd0;
                    done <= 1'b0;
                    overflow_flag <= 1'b0;
                end
            endcase
        end
    end

endmodule