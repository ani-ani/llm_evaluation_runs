module FairNutAndStrings(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] s,
    input wire [15:0] t,
    input wire [3:0] n,
    input wire [8:0] k,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [3:0] i;  // Bit position counter (0-15)
    reg [9:0] count;  // 10-bit count (max 256)
    reg [23:0] result_acc;  // 24-bit accumulator
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            count <= 10'd0;
            result_acc <= 24'd0;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 4'd0;
                        count <= 10'd1;  // Initialize count to 1
                        result_acc <= 24'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current bit position
                    if (i < n) begin
                        // Update count
                        count <= count * 2'd2;
                        
                        // Subtract based on s[i] and t[i]
                        if (s[i] == 1'b0) begin
                            count <= count - 10'd1;
                        end
                        
                        if (t[i] == 1'b1) begin
                            count <= count - 10'd1;
                        end
                        
                        // Cap count at k
                        if (count > k) begin
                            count <= k;
                        end
                        
                        // Add to result
                        if (count < k) begin
                            result_acc <= result_acc + count;
                        end else begin
                            result_acc <= result_acc + k;
                        end
                        
                        // Move to next bit
                        i <= i + 4'd1;
                    end else begin
                        // All bits processed
                        state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= result_acc;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule