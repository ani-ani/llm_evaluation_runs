module search_max_valid(
    input clk,
    input rst_n,
    input start,
    input [3:0] data_in,
    input [3:0] index,
    input valid_in,
    input done_in,
    output reg [7:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] CHECK = 2'd2;
    
    reg [1:0] state;
    reg [3:0] counter;
    reg [4:0] freq [0:15];  // 5-bit counters for values 0-15
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            counter <= 4'd0;
            // Frequency array initialization
            for (i = 0; i < 16; i = i + 1) begin
                freq[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset frequency counters on start
                        for (i = 0; i < 16; i = i + 1) begin
                            freq[i] <= 5'd0;
                        end
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Update frequency on valid inputs
                    if (valid_in && (data_in != 4'd0)) begin
                        freq[data_in] <= freq[data_in] + 5'd1;
                    end
                    
                    if (done_in) begin
                        state <= CHECK;
                        counter <= 4'd15;  // Start with max value 15
                    end
                end
                
                CHECK: begin
                    if (counter >= 4'd1) begin
                        if (freq[counter] >= counter) begin  // Found valid X
                            result <= {4'd0, counter};
                            done <= 1'b1;
                            state <= IDLE;
                        end else if (counter == 4'd1) begin  // Last value failed
                            result <= 8'hFF;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin  // Continue checking
                            counter <= counter - 4'd1;
                        end
                    end else begin  // Safeguard against invalid counter
                        result <= 8'hFF;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule