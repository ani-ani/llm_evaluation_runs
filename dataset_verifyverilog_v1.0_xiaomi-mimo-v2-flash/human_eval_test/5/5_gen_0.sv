module intersperse (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in [0:15],
    input wire [3:0] len_in,
    input wire [7:0] delim,
    output reg [7:0] arr_out [0:31],
    output reg [4:0] len_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [4:0] idx_out;          // Index for arr_out (0-31)
    reg [3:0] idx_in;           // Index for arr_in (0-15)
    reg [4:0] max_idx_out;      // Maximum output index needed
    reg [3:0] cycle_count;      // Cycle counter for timeout prevention
    localparam [3:0] MAX_CYCLES = 4'd20;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end else begin
                    next_state = IDLE;
                end
            end
            PROCESS: begin
                if (idx_out >= max_idx_out) begin
                    next_state = FINISH;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = PROCESS;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            len_out <= 5'd0;
            idx_out <= 5'd0;
            idx_in <= 4'd0;
            max_idx_out <= 5'd0;
            cycle_count <= 4'd0;
            // Initialize all arr_out elements to 0
            arr_out[0] <= 8'd0;  arr_out[1] <= 8'd0;  arr_out[2] <= 8'd0;  arr_out[3] <= 8'd0;
            arr_out[4] <= 8'd0;  arr_out[5] <= 8'd0;  arr_out[6] <= 8'd0;  arr_out[7] <= 8'd0;
            arr_out[8] <= 8'd0;  arr_out[9] <= 8'd0;  arr_out[10] <= 8'd0; arr_out[11] <= 8'd0;
            arr_out[12] <= 8'd0; arr_out[13] <= 8'd0; arr_out[14] <= 8'd0; arr_out[15] <= 8'd0;
            arr_out[16] <= 8'd0; arr_out[17] <= 8'd0; arr_out[18] <= 8'd0; arr_out[19] <= 8'd0;
            arr_out[20] <= 8'd0; arr_out[21] <= 8'd0; arr_out[22] <= 8'd0; arr_out[23] <= 8'd0;
            arr_out[24] <= 8'd0; arr_out[25] <= 8'd0; arr_out[26] <= 8'd0; arr_out[27] <= 8'd0;
            arr_out[28] <= 8'd0; arr_out[29] <= 8'd0; arr_out[30] <= 8'd0; arr_out[31] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        idx_out <= 5'd0;
                        idx_in <= 4'd0;
                        if (len_in == 4'd0) begin
                            max_idx_out <= 5'd0;
                            len_out <= 5'd0;
                            // arr_out already zeroed from reset
                            // No processing needed, go to finish immediately
                        end else begin
                            max_idx_out <= 5'd21;  // 2*len_in - 2 (for len_in=16, max_idx=30)
                            // Actually 2*len_in - 2 = 30 for len_in=16
                        end
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (len_in > 4'd0) begin
                        // For odd output indices: place element from arr_in
                        if (idx_out[0] == 1'b0) begin
                            // Even index (0, 2, 4, ...): arr_in element
                            arr_out[idx_out] <= arr_in[idx_in];
                            if (idx_in < (len_in - 4'd1)) begin
                                idx_in <= idx_in + 4'd1;
                            end
                        end else begin
                            // Odd index (1, 3, 5, ...): delimiter
                            arr_out[idx_out] <= delim;
                            // idx_in unchanged for delimiter
                        end
                        
                        idx_out <= idx_out + 5'd1;
                        
                        // Calculate when to stop
                        if (idx_out == (2 * len_in - 5'd1)) begin
                            len_out <= 2 * len_in - 5'd1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
endmodule