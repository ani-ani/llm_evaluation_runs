module largest_negative_smallest_positive (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire signed [7:0] arr [0:15],
    output reg signed [7:0] neg_val,
    output reg neg_valid,
    output reg signed [7:0] pos_val,
    output reg pos_valid,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCANNING = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] counter;
    reg signed [7:0] max_neg;
    reg signed [7:0] min_pos;
    reg neg_found;
    reg pos_found;
    reg signed [7:0] current_val;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            counter <= 4'd0;
            max_neg <= 8'sd0;
            min_pos <= 8'sd0;
            neg_found <= 1'b0;
            pos_found <= 1'b0;
            current_val <= 8'sd0;
            neg_val <= 8'sd0;
            neg_valid <= 1'b0;
            pos_val <= 8'sd0;
            pos_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize scanning
                        state <= SCANNING;
                        counter <= 4'd0;
                        max_neg <= 8'sd127; // Initialize to max possible negative (closest to zero)
                        min_pos <= 8'sd127; // Initialize to max possible positive
                        neg_found <= 1'b0;
                        pos_found <= 1'b0;
                    end
                end
                
                SCANNING: begin
                    if (counter < len) begin
                        // Read current array element
                        current_val <= arr[counter];
                        
                        // Check for negative integers
                        if (arr[counter] < 8'sd0) begin
                            if (!neg_found || (arr[counter] > max_neg)) begin
                                max_neg <= arr[counter];
                                neg_found <= 1'b1;
                            end
                        end
                        
                        // Check for positive integers
                        if (arr[counter] > 8'sd0) begin
                            if (!pos_found || (arr[counter] < min_pos)) begin
                                min_pos <= arr[counter];
                                pos_found <= 1'b1;
                            end
                        end
                        
                        // Increment counter
                        counter <= counter + 4'd1;
                    end else begin
                        // Done scanning, move to finish state
                        state <= FINISH;
                        counter <= 4'd0;
                    end
                end
                
                FINISH: begin
                    // Copy results to outputs
                    neg_val <= max_neg;
                    neg_valid <= neg_found;
                    pos_val <= min_pos;
                    pos_valid <= pos_found;
                    done <= 1'b1;
                    
                    // Return to idle
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule