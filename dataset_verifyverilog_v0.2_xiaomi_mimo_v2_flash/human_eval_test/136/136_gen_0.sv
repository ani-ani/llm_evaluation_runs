module largest_smallest_integers (
    input clk,
    input rst_n,
    input start,
    input [7:0][15:0] data_in,
    output reg [31:0] largest_negative,
    output reg [31:0] smallest_positive,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [2:0] counter; // 0 to 7 for 8 elements
    reg signed [15:0] current_val;
    wire signed [31:0] current_val_ext;
    
    // Internal registers for results
    reg signed [31:0] largest_neg_reg;
    reg signed [31:0] smallest_pos_reg;
    
    // Sign extension for comparison
    assign current_val_ext = {{16{data_in[counter][15]}}, data_in[counter]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            largest_negative <= 32'h80000000;
            smallest_positive <= 32'h80000000;
            largest_neg_reg <= 32'h80000000;
            smallest_pos_reg <= 32'h80000000;
            counter <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        counter <= 3'b0;
                        largest_neg_reg <= 32'h80000000;
                        smallest_pos_reg <= 32'h80000000;
                    end
                end
                
                PROCESSING: begin
                    // Process current element
                    if (current_val_ext < 0) begin
                        // Update largest_negative: max(current, new_value)
                        // Since both are negative, larger means closer to zero (less negative)
                        if ($signed(current_val_ext) > largest_neg_reg) begin
                            largest_neg_reg <= current_val_ext;
                        end
                    end else if (current_val_ext > 0) begin
                        // Update smallest_positive: min(current, new_value)
                        if ($signed(current_val_ext) < smallest_pos_reg) begin
                            smallest_pos_reg <= current_val_ext;
                        end
                    end
                    // Note: if value == 0, ignore
                    
                    if (counter == 3'd7) begin
                        state <= DONE;
                        done <= 1'b1;
                        largest_negative <= largest_neg_reg;
                        smallest_positive <= smallest_pos_reg;
                    end else begin
                        counter <= counter + 1'b1;
                    end
                end
                
                DONE: begin
                    // Wait for reset or new start
                    // When start comes, FSM transitions in IDLE state logic above
                    if (start) begin
                        state <= PROCESSING;
                        counter <= 3'b0;
                        largest_neg_reg <= 32'h80000000;
                        smallest_pos_reg <= 32'h80000000;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule