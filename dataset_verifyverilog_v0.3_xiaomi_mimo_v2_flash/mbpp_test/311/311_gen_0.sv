module set_left_most_unset_bit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [31:0] temp_n;
    reg [4:0] pos;           // Position counter (0-31)
    reg [4:0] found_pos;     // Store the leftmost unset bit position
    reg all_set_flag;        // Flag to indicate all bits are set
    reg [4:0] cycle_count;   // Cycle counter

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            temp_n <= 32'd0;
            pos <= 5'd0;
            found_pos <= 5'd0;
            all_set_flag <= 1'b0;
            cycle_count <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        temp_n <= n;
                        pos <= 5'd0;
                        found_pos <= 5'd0;
                        // Check if n == 32'hFFFFFFFF (all bits set)
                        if (n == 32'hFFFFFFFF) begin
                            all_set_flag <= 1'b1;
                        end else begin
                            all_set_flag <= 1'b0;
                        end
                    end
                end
                
                CHECK: begin
                    // Scan from MSB to find leftmost unset bit
                    if (pos < 5'd31) begin
                        if (!temp_n[31]) begin
                            found_pos <= pos;
                        end
                        // Shift left to check next bit
                        temp_n[31] <= temp_n[30];
                        temp_n[30] <= temp_n[29];
                        temp_n[29] <= temp_n[28];
                        temp_n[28] <= temp_n[27];
                        temp_n[27] <= temp_n[26];
                        temp_n[26] <= temp_n[25];
                        temp_n[25] <= temp_n[24];
                        temp_n[24] <= temp_n[23];
                        temp_n[23] <= temp_n[22];
                        temp_n[22] <= temp_n[21];
                        temp_n[21] <= temp_n[20];
                        temp_n[20] <= temp_n[19];
                        temp_n[19] <= temp_n[18];
                        temp_n[18] <= temp_n[17];
                        temp_n[17] <= temp_n[16];
                        temp_n[16] <= temp_n[15];
                        temp_n[15] <= temp_n[14];
                        temp_n[14] <= temp_n[13];
                        temp_n[13] <= temp_n[12];
                        temp_n[12] <= temp_n[11];
                        temp_n[11] <= temp_n[10];
                        temp_n[10] <= temp_n[9];
                        temp_n[9] <= temp_n[8];
                        temp_n[8] <= temp_n[7];
                        temp_n[7] <= temp_n[6];
                        temp_n[6] <= temp_n[5];
                        temp_n[5] <= temp_n[4];
                        temp_n[4] <= temp_n[3];
                        temp_n[3] <= temp_n[2];
                        temp_n[2] <= temp_n[1];
                        temp_n[1] <= temp_n[0];
                        temp_n[0] <= 1'b1;  // Shift in 1 from left
                        pos <= pos + 5'd1;
                    end else begin
                        // Check bit 31 one more time
                        if (!temp_n[31]) begin
                            found_pos <= pos;
                        end
                    end
                    cycle_count <= cycle_count + 5'd1;
                end
                
                COMPUTE: begin
                    // Set the leftmost unset bit
                    if (!all_set_flag) begin
                        result <= n | (32'd1 << found_pos);
                    end else begin
                        result <= n; // All bits set, return as is
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CHECK;
                else next_state = IDLE;
            end
            
            CHECK: begin
                if (pos >= 5'd31 || cycle_count >= 5'd31) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = CHECK;
                end
            end
            
            COMPUTE: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule