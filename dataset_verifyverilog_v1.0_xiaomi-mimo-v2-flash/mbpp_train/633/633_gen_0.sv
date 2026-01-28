module pair_xor_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] i_idx;           // Outer loop index
    reg [3:0] j_idx;           // Inner loop index
    reg [31:0] acc_result;     // Accumulator for result
    reg [7:0] pair_xor;        // Current pair XOR value
    reg [7:0] cycle_count;     // Cycle counter for timeout
    
    // Control signals
    reg compute_xor;
    reg add_to_acc;
    reg i_next;
    reg j_next;
    
    // FSM: Synchronous logic with asynchronous reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            acc_result <= 32'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            pair_xor <= 8'd0;
            cycle_count <= 8'd0;
            compute_xor <= 1'b0;
            add_to_acc <= 1'b0;
            i_next <= 1'b0;
            j_next <= 1'b0;
        end else begin
            // Reset control signals
            compute_xor <= 1'b0;
            add_to_acc <= 1'b0;
            i_next <= 1'b0;
            j_next <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                    acc_result <= 32'd0;
                    i_idx <= 4'd0;
                    j_idx <= 4'd0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Check for empty or single-element array
                        if (len < 4'd2) begin
                            state <= DONE;
                        end else begin
                            state <= COMPUTE;
                            compute_xor <= 1'b0;  // First cycle just sets up
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute XOR for current pair
                    if (!compute_xor && !add_to_acc) begin
                        pair_xor <= arr[i_idx] ^ arr[j_idx];
                        compute_xor <= 1'b1;
                    end
                    
                    // Add to accumulator (1 cycle after XOR)
                    if (compute_xor && !add_to_acc) begin
                        acc_result <= acc_result + {24'd0, pair_xor};
                        add_to_acc <= 1'b1;
                        
                        // Move to next pair
                        if (j_idx < len - 4'd1) begin
                            j_idx <= j_idx + 4'd1;
                        end else begin
                            // Finished current i, move to next i
                            j_idx <= i_idx + 4'd2;  // Reset j for next i
                            i_idx <= i_idx + 4'd1;
                            i_next <= 1'b1;
                            j_next <= 1'b1;
                        end
                        
                        // Check completion conditions
                        if ((i_idx >= len - 4'd1) || (cycle_count >= 8'd190)) begin
                            state <= DONE;
                        end
                    end
                    
                    // Handle timeout (safety mechanism)
                    if (cycle_count >= 8'd190) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result <= acc_result;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
        end
    end

endmodule