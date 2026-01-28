module NephrenGame(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [63:0] k,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] DONE_STATE = 3'd2;

    // Constants
    localparam [15:0] MAX_DEPTH = 16'd55;
    localparam [63:0] SATURATION_VALUE = 64'd4611686018427387904; // 2^62
    localparam [63:0] CLK_CYCLES = 64'd1000;

    // String constants (stored as byte arrays)
    reg [7:0] f0 [0:74];
    reg [7:0] prefix [0:33];
    reg [7:0] middle [0:31];
    reg [7:0] suffix [0:1];

    // Length table ROM (precomputed for n=0 to 54)
    reg [63:0] length_table [0:54];

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] current_n;
    reg [63:0] current_k;
    reg [63:0] cycle_count;
    reg [63:0] temp_length;

    // Initialize string constants
    integer i;
    initial begin
        // f0 = "What are you doing at the end of the world? Are you busy? Will you save us?"
        f0[0] = 8'd87; f0[1] = 8'd104; f0[2] = 8'd97; f0[3] = 8'd116; f0[4] = 8'd32;
        f0[5] = 8'd97; f0[6] = 8'd114; f0[7] = 8'd101; f0[8] = 8'd32; f0[9] = 8'd121;
        f0[10] = 8'd111; f0[11] = 8'd117; f0[12] = 8'd32; f0[13] = 8'd100; f0[14] = 8'd111;
        f0[15] = 8'd105; f0[16] = 8'd110; f0[17] = 8'd103; f0[18] = 8'd32; f0[19] = 8'd97;
        f0[20] = 8'd116; f0[21] = 8'd32; f0[22] = 8'd116; f0[23] = 8'd104; f0[24] = 8'd101;
        f0[25] = 8'd32; f0[26] = 8'd101; f0[27] = 8'd110; f0[28] = 8'd100; f0[29] = 8'd32;
        f0[30] = 8'd111; f0[31] = 8'd102; f0[32] = 8'd32; f0[33] = 8'd116; f0[34] = 8'd104;
        f0[35] = 8'd101; f0[36] = 8'd32; f0[37] = 8'd119; f0[38] = 8'd111; f0[39] = 8'd114;
        f0[40] = 8'd108; f0[41] = 8'd100; f0[42] = 8'd63; f0[43] = 8'd32; f0[44] = 8'd65;
        f0[45] = 8'd114; f0[46] = 8'd101; f0[47] = 8'd32; f0[48] = 8'd121; f0[49] = 8'd111;
        f0[50] = 8'd117; f0[51] = 8'd32; f0[52] = 8'd98; f0[53] = 8'd117; f0[54] = 8'd115;
        f0[55] = 8'd121; f0[56] = 8'd63; f0[57] = 8'd32; f0[58] = 8'd87; f0[59] = 8'd105;
        f0[60] = 8'd108; f0[61] = 8'd108; f0[62] = 8'd32; f0[63] = 8'd121; f0[64] = 8'd111;
        f0[65] = 8'd117; f0[66] = 8'd32; f0[67] = 8'd115; f0[68] = 8'd97; f0[69] = 8'd118;
        f0[70] = 8'd101; f0[71] = 8'd32; f0[72] = 8'd117; f0[73] = 8'd115; f0[74] = 8'd63;

        // prefix = "What are you doing while sending \""
        prefix[0] = 8'd87; prefix[1] = 8'd104; prefix[2] = 8'd97; prefix[3] = 8'd116; prefix[4] = 8'd32;
        prefix[5] = 8'd97; prefix[6] = 8'd114; prefix[7] = 8'd101; prefix[8] = 8'd32; prefix[9] = 8'd121;
        prefix[10] = 8'd111; prefix[11] = 8'd117; prefix[12] = 8'd32; prefix[13] = 8'd100; prefix[14] = 8'd111;
        prefix[15] = 8'd105; prefix[16] = 8'd110; prefix[17] = 8'd103; prefix[18] = 8'd32; prefix[19] = 8'd119;
        prefix[20] = 8'd104; prefix[21] = 8'd105; prefix[22] = 8'd108; prefix[23] = 8'd101; prefix[24] = 8'd32;
        prefix[25] = 8'd115; prefix[26] = 8'd101; prefix[27] = 8'd110; prefix[28] = 8'd100; prefix[29] = 8'd105;
        prefix[30] = 8'd110; prefix[31] = 8'd103; prefix[32] = 8'd32; prefix[33] = 8'd34;

        // middle = "\"? Are you busy? Will you send \""
        middle[0] = 8'd34; middle[1] = 8'd63; middle[2] = 8'd32; middle[3] = 8'd65; middle[4] = 8'd114;
        middle[5] = 8'd101; middle[6] = 8'd32; middle[7] = 8'd121; middle[8] = 8'd111; middle[9] = 8'd117;
        middle[10] = 8'd32; middle[11] = 8'd98; middle[12] = 8'd117; middle[13] = 8'd115; middle[14] = 8'd121;
        middle[15] = 8'd63; middle[16] = 8'd32; middle[17] = 8'd87; middle[18] = 8'd105; middle[19] = 8'd108;
        middle[20] = 8'd108; middle[21] = 8'd32; middle[22] = 8'd121; middle[23] = 8'd111; middle[24] = 8'd117;
        middle[25] = 8'd32; middle[26] = 8'd115; middle[27] = 8'd101; middle[28] = 8'd110; middle[29] = 8'd100;
        middle[30] = 8'd32; middle[31] = 8'd34;

        // suffix = "\"?"
        suffix[0] = 8'd34; suffix[1] = 8'd63;

        // Precompute length table
        length_table[0] = 64'd75;
        for (i = 1; i <= 54; i = i + 1) begin
            length_table[i] = (length_table[i-1] << 1) + 64'd68;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 64'd0;
            current_n <= 16'd0;
            current_k <= 64'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 64'd0;
                    if (start) begin
                        current_n <= n;
                        current_k <= k;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 64'd1;
                    
                    // Check if k exceeds length
                    if (current_n >= MAX_DEPTH) begin
                        temp_length = SATURATION_VALUE;
                    end else begin
                        temp_length = length_table[current_n];
                    end
                    
                    if (current_k > temp_length) begin
                        result <= 8'd46; // '.'
                        next_state <= DONE_STATE;
                    end else if (current_n == 0) begin
                        // Base case: f0
                        if (current_k >= 1 && current_k <= 75) begin
                            result <= f0[current_k - 1];
                        end else begin
                            result <= 8'd46; // '.'
                        end
                        next_state <= DONE_STATE;
                    end else begin
                        // Recursive case: f_i for i >= 1
                        if (current_k <= 34) begin
                            // In prefix
                            result <= prefix[current_k - 1];
                            next_state <= DONE_STATE;
                        end else begin
                            current_k <= current_k - 34;
                            
                            if (current_k <= temp_length - 68) begin
                                // In first f_{n-1}
                                current_n <= current_n - 1;
                                next_state <= COMPUTE;
                            end else begin
                                current_k <= current_k - (temp_length - 68);
                                
                                if (current_k <= 32) begin
                                    // In middle
                                    result <= middle[current_k - 1];
                                    next_state <= DONE_STATE;
                                end else begin
                                    current_k <= current_k - 32;
                                    
                                    if (current_k <= temp_length - 68) begin
                                        // In second f_{n-1}
                                        current_n <= current_n - 1;
                                        next_state <= COMPUTE;
                                    end else begin
                                        current_k <= current_k - (temp_length - 68);
                                        
                                        if (current_k <= 2) begin
                                            // In suffix
                                            result <= suffix[current_k - 1];
                                        end else begin
                                            result <= 8'd46; // '.'
                                        end
                                        next_state <= DONE_STATE;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Safety check for cycle count
                    if (cycle_count >= CLK_CYCLES) begin
                        result <= 8'd46; // '.'
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 8'd0;
                end
            endcase
        end
    end

endmodule