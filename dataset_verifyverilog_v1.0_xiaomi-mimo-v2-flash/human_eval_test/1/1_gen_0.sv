module paren_parser(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_end,
    output reg group_start,
    output reg group_end,
    output reg done,
    output reg [15:0] result
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [4:0] balance;           // Balance counter (max 31)
    reg [4:0] max_balance;       // Track maximum balance
    reg [3:0] group_count;       // Count completed groups
    reg [4:0] char_counter;      // Character counter (max 16)
    reg [15:0] result_reg;       // Result register
    
    // Wire for next balance calculation
    wire [4:0] next_balance;
    wire [4:0] next_max_balance;
    
    // Combinational logic for next values
    assign next_balance = (char_in == 8'h28) ? (balance + 5'd1) : 
                          (char_in == 8'h29) ? (balance - 5'd1) : balance;
    
    assign next_max_balance = (next_balance > max_balance) ? next_balance : max_balance;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            group_start <= 1'b0;
            group_end <= 1'b0;
            done <= 1'b0;
            result <= 16'd0;
            balance <= 5'd0;
            max_balance <= 5'd0;
            group_count <= 4'd0;
            char_counter <= 5'd0;
            result_reg <= 16'd0;
        end else begin
            // Default pulse outputs to 0
            group_start <= 1'b0;
            group_end <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    balance <= 5'd0;
                    max_balance <= 5'd0;
                    group_count <= 4'd0;
                    char_counter <= 5'd0;
                    result_reg <= 16'd0;
                    
                    if (start) begin
                        state <= READING;
                    end
                end
                
                READING: begin
                    if (char_valid && char_counter < 5'd16) begin
                        // Process character
                        if (char_in == 8'h28) begin  // '(' 
                            if (balance == 5'd0) begin
                                group_start <= 1'b1;
                            end
                            balance <= balance + 5'd1;
                        end else if (char_in == 8'h29) begin  // ')'
                            if (balance == 5'd1) begin
                                group_end <= 1'b1;
                                group_count <= group_count + 4'd1;
                            end
                            balance <= balance - 5'd1;
                        end
                        // Ignore spaces (0x20) and other characters
                        
                        // Update max balance
                        if (balance > max_balance) begin
                            max_balance <= balance;
                        end
                        
                        char_counter <= char_counter + 5'd1;
                    end
                    
                    // Check for end of string
                    if (char_end) begin
                        if (balance == 5'd0) begin
                            result_reg <= {max_balance[3:0], group_count};
                            result <= {max_balance[3:0], group_count};
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            // Unbalanced - still done but with error indication
                            result_reg <= {max_balance[3:0], group_count};
                            result <= {max_balance[3:0], group_count};
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    // Return to IDLE
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule