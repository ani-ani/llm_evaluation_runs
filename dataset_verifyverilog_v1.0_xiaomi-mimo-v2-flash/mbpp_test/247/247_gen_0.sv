module LPS_Compute (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] str,
    input wire [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] MAIN_LOOP = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [3:0] i_idx;          // Row index
    reg [3:0] j_idx;          // Column index
    reg [3:0] cl;             // Current length
    reg [3:0] len_reg;        // Stored length
    reg [127:0] str_reg;      // Stored string
    reg [3:0] dp_table [0:255]; // 16x16 flattened DP table
    reg [7:0] cycle_count;    // Prevent infinite loops
    
    // Character extraction from packed string (combinational)
    wire [7:0] char_i;
    wire [7:0] char_j;
    
    // Extract characters based on indices
    assign char_i = str_reg[(i_idx << 3) +: 8];
    assign char_j = str_reg[(j_idx << 3) +: 8];

    // Combinational logic for DP value calculation
    reg [3:0] dp_i1_jm1;
    reg [3:0] dp_i_jm1;
    reg [3:0] dp_i1_j;
    reg [3:0] new_dp_value;
    
    always @(*) begin
        // Read DP values for calculation
        if (i_idx + 1 <= j_idx - 1) begin
            dp_i1_jm1 = dp_table[((i_idx + 1) * 16) + (j_idx - 1)];
        end else begin
            dp_i1_jm1 = 4'd0;
        end
        
        if (j_idx > 0) begin
            dp_i_jm1 = dp_table[(i_idx * 16) + (j_idx - 1)];
        end else begin
            dp_i_jm1 = 4'd0;
        end
        
        if (i_idx + 1 < 16) begin
            dp_i1_j = dp_table[((i_idx + 1) * 16) + j_idx];
        end else begin
            dp_i1_j = 4'd0;
        end
        
        // LPS Logic: if chars match, 2 + L[i+1][j-1], else max(L[i+1][j], L[i][j-1])
        if (char_i == char_j) begin
            new_dp_value = (dp_i1_jm1 + 2'd2);
        end else begin
            if (dp_i1_j > dp_i_jm1) begin
                new_dp_value = dp_i1_j;
            end else begin
                new_dp_value = dp_i_jm1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            cl <= 4'd0;
            len_reg <= 4'd0;
            str_reg <= 128'd0;
            cycle_count <= 8'd0;
            // Reset DP table
            for (int k = 0; k < 256; k = k + 1) begin
                dp_table[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        len_reg <= len;
                        str_reg <= str;
                        
                        // Handle edge cases immediately
                        if (len <= 4'd1) begin
                            state <= COMPLETE;
                            if (len == 4'd0)
                                result <= 4'd0;
                            else
                                result <= 4'd1;
                        end else begin
                            state <= INIT;
                            i_idx <= 4'd0;
                        end
                    end
                end
                
                INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Clear table entry (already reset in main block)
                    dp_table[(i_idx * 16) + i_idx] <= 4'd1;
                    
                    i_idx <= i_idx + 4'd1;
                    
                    // Check if initialization is complete (5 cycles max)
                    if (i_idx == len_reg - 4'd1 || cycle_count >= 8'd5) begin
                        state <= MAIN_LOOP;
                        cl <= 4'd2;
                        cycle_count <= 8'd0;
                    end
                end
                
                MAIN_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate j = i + cl - 1
                    j_idx <= i_idx + cl - 4'd1;
                    
                    // Write computed DP value
                    if (cl >= 4'd2 && i_idx <= len_reg - cl) begin
                        dp_table[(i_idx * 16) + j_idx] <= new_dp_value;
                    end
                    
                    // Increment i
                    i_idx <= i_idx + 4'd1;
                    
                    // Check if current cl iteration is complete
                    if (i_idx >= len_reg - cl) begin
                        // Move to next cl
                        cl <= cl + 4'd1;
                        i_idx <= 4'd0;
                        
                        // Check if all lengths processed
                        if (cl >= len_reg) begin
                            state <= COMPLETE;
                            result <= dp_table[(0 * 16) + (len_reg - 4'd1)];
                        end
                    end
                    
                    // Safety timeout
                    if (cycle_count >= 8'd250) begin
                        state <= COMPLETE;
                        result <= dp_table[(0 * 16) + (len_reg - 4'd1)];
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule