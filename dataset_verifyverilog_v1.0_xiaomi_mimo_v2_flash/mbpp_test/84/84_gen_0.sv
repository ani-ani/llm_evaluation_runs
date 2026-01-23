module newman_conway_seq(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    output reg [7:0] result,
    output reg done
);

    // Newman-Conway Sequence: P(1)=P(2)=1, P(n)=P(P(n-1)) + P(n-P(n-1))
    // Maximum n = 16 (fits in 5 bits)
    // Uses dynamic programming with internal memory
    
    reg [4:0] i;  // Current index being computed
    reg [7:0] p [15:0];  // Lookup table, p[k] = P(k+1)
    reg [1:0] state;
    reg [2:0] substate;  // For multi-cycle computation
    
    // States
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Substates for computing P(i) = P(P(i-1)) + P(i-P(i-1))
    localparam [2:0] READ1 = 3'd0;  // Read P(i-1)
    localparam [2:0] READ2 = 3'd1;  // Read P(P(i-1)) and P(i-P(i-1))
    localparam [2:0] WRITE = 3'd2;  // Write sum
    
    reg [7:0] val_i_minus_1;
    reg [7:0] p_of_val;
    reg [7:0] p_of_diff;
    
    integer idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            substate <= READ1;
            done <= 1'b0;
            result <= 8'd0;
            i <= 5'd0;
            val_i_minus_1 <= 8'd0;
            p_of_val <= 8'd0;
            p_of_diff <= 8'd0;
            // Initialize base cases
            p[0] <= 8'd1;  // P(1)
            p[1] <= 8'd1;  // P(2)
            // Clear remaining array
            for (idx = 2; idx < 16; idx = idx + 1) begin
                p[idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && n >= 5'd1 && n <= 5'd16) begin
                        if (n == 5'd1 || n == 5'd2) begin
                            result <= 8'd1;
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            i <= 5'd3;
                            substate <= READ1;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    case (substate)
                        READ1: begin
                            // Read P(i-1)
                            val_i_minus_1 <= p[i-2];  // p[i-2] = P(i-1)
                            substate <= READ2;
                        end
                        
                        READ2: begin
                            // Read P(P(i-1)) and P(i-P(i-1))
                            // P(P(i-1)) = P(val_i_minus_1) = p[val_i_minus_1 - 1]
                            // P(i-P(i-1)) = P(i - val_i_minus_1) = p[i - val_i_minus_1 - 1]
                            p_of_val <= p[val_i_minus_1 - 1];  // P(P(i-1))
                            p_of_diff <= p[i - val_i_minus_1 - 1];  // P(i-P(i-1))
                            substate <= WRITE;
                        end
                        
                        WRITE: begin
                            // Compute and store P(i)
                            p[i-1] <= p_of_val + p_of_diff;
                            
                            if (i == n) begin
                                result <= p_of_val + p_of_diff;
                                done <= 1'b1;
                                state <= DONE_STATE;
                            end else begin
                                i <= i + 1;
                                substate <= READ1;
                            end
                        end
                        
                        default: begin
                            substate <= READ1;
                        end
                    endcase
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule