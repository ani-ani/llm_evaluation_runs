module next_smallest_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:7],
    input wire [3:0] len,
    output reg signed [7:0] result,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg signed [7:0] min1;
    reg signed [7:0] min2;
    reg found_min1;
    reg found_min2;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'sd0;
            valid <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            min1 <= 8'sd0;
            min2 <= 8'sd0;
            found_min1 <= 1'b0;
            found_min2 <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (len >= 4'd2) begin
                            // Initialize min1 and min2 with first two distinct values
                            min1 <= arr[0];
                            found_min1 <= 1'b1;
                            index <= 4'd1;
                            // Find first distinct value for min2
                            if (len > 4'd1 && arr[1] != arr[0]) begin
                                min2 <= arr[1];
                                found_min2 <= 1'b1;
                                state <= DONE;
                                valid <= 1'b1;
                                result <= arr[1];
                                done <= 1'b1;
                            end else if (len > 4'd1 && arr[1] == arr[0]) begin
                                // Same as min1, continue searching
                                state <= PROCESSING;
                            end else begin
                                // len is exactly 2 but both equal
                                valid <= 1'b0;
                                state <= DONE;
                                done <= 1'b1;
                            end
                        end else begin
                            // len < 2
                            valid <= 1'b0;
                            state <= DONE;
                            done <= 1'b1;
                        end
                    end
                end
                
                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                        done <= 1'b1;
                        valid <= 1'b0;
                    end else if (index < len) begin
                        if (arr[index] < min1 && arr[index] != min1) begin
                            // Found new minimum
                            min1 <= arr[index];
                            // If we had found a min2, it stays
                            // But need to update min2 logic
                            if (found_min2 && arr[index] < min2) begin
                                min2 <= min1; // Previous min1 becomes min2
                            end
                        end else if (arr[index] > min1 && arr[index] < min2 && arr[index] != min1 && arr[index] != min2) begin
                            // Found new candidate for second smallest
                            if (!found_min2 || arr[index] < min2) begin
                                min2 <= arr[index];
                                found_min2 <= 1'b1;
                            end
                        end else if (arr[index] == min1 && !found_min1) begin
                            // Shouldn't happen, we already set found_min1
                        end else if (arr[index] == min2 && found_min2) begin
                            // Duplicate of min2, ignore
                        end else if (arr[index] != min1 && !found_min2) begin
                            // Found first distinct from min1
                            if (arr[index] < min1) begin
                                // This case is handled above, but for safety
                                min1 <= arr[index];
                            end else begin
                                min2 <= arr[index];
                                found_min2 <= 1'b1;
                            end
                        end
                        
                        index <= index + 4'd1;
                    end else begin
                        // Finished iteration
                        if (found_min2) begin
                            valid <= 1'b1;
                            result <= min2;
                        end else begin
                            valid <= 1'b0;
                        end
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                
                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule