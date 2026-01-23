module triple_correlation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] p,
    input wire [3:0] seq_0,
    input wire [3:0] seq_1,
    input wire [3:0] seq_2,
    input wire [3:0] seq_3,
    input wire [3:0] seq_4,
    input wire [3:0] seq_5,
    input wire [3:0] seq_6,
    input wire [3:0] seq_7,
    input wire [3:0] seq_8,
    input wire [3:0] seq_9,
    input wire [3:0] seq_10,
    input wire [3:0] seq_11,
    input wire [3:0] seq_12,
    input wire [3:0] seq_13,
    input wire [3:0] seq_14,
    input wire [3:0] seq_15,
    input wire [3:0] seq_16,
    input wire [3:0] seq_17,
    input wire [3:0] seq_18,
    input wire [3:0] seq_19,
    output reg found,
    output reg [3:0] a_out,
    output reg [3:0] b_out,
    output reg [3:0] c_out,
    output reg [7:0] n_out,
    output reg [7:0] m_out,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] INIT_SEARCH = 4'd2;
    localparam [3:0] SCANNING = 4'd3;
    localparam [3:0] EVALUATE = 4'd4;
    localparam [3:0] NEXT_C = 4'd5;
    localparam [3:0] NEXT_B = 4'd6;
    localparam [3:0] NEXT_A = 4'd7;
    localparam [3:0] NEXT_M = 4'd8;
    localparam [3:0] NEXT_N = 4'd9;
    localparam [3:0] DONE = 4'd10;
    
    // Internal registers
    reg [3:0] seq_reg [0:19];
    reg [7:0] p_reg;
    reg [7:0] T;
    reg [7:0] n_reg, m_reg;
    reg [3:0] a_reg, b_reg, c_reg;
    reg [7:0] i;
    reg [7:0] triple_count;
    reg [7:0] first_i;
    reg candidate_valid;
    reg [3:0] best_a, best_b, best_c;
    reg [7:0] best_n, best_m, best_first_i;
    reg [3:0] state;
    reg [7:0] cycle_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            found <= 1'b0;
            a_out <= 4'd0;
            b_out <= 4'd0;
            c_out <= 4'd0;
            n_out <= 8'd0;
            m_out <= 8'd0;
            p_reg <= 8'd0;
            T <= 8'd0;
            n_reg <= 8'd0;
            m_reg <= 8'd0;
            a_reg <= 4'd0;
            b_reg <= 4'd0;
            c_reg <= 4'd0;
            i <= 8'd0;
            triple_count <= 8'd0;
            first_i <= 8'd0;
            candidate_valid <= 1'b0;
            best_a <= 4'd0;
            best_b <= 4'd0;
            best_c <= 4'd0;
            best_n <= 8'd0;
            best_m <= 8'd0;
            best_first_i <= 8'd21;
            cycle_counter <= 8'd0;
            seq_reg[0] <= 4'd0;
            seq_reg[1] <= 4'd0;
            seq_reg[2] <= 4'd0;
            seq_reg[3] <= 4'd0;
            seq_reg[4] <= 4'd0;
            seq_reg[5] <= 4'd0;
            seq_reg[6] <= 4'd0;
            seq_reg[7] <= 4'd0;
            seq_reg[8] <= 4'd0;
            seq_reg[9] <= 4'd0;
            seq_reg[10] <= 4'd0;
            seq_reg[11] <= 4'd0;
            seq_reg[12] <= 4'd0;
            seq_reg[13] <= 4'd0;
            seq_reg[14] <= 4'd0;
            seq_reg[15] <= 4'd0;
            seq_reg[16] <= 4'd0;
            seq_reg[17] <= 4'd0;
            seq_reg[18] <= 4'd0;
            seq_reg[19] <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    seq_reg[0] <= seq_0;
                    seq_reg[1] <= seq_1;
                    seq_reg[2] <= seq_2;
                    seq_reg[3] <= seq_3;
                    seq_reg[4] <= seq_4;
                    seq_reg[5] <= seq_5;
                    seq_reg[6] <= seq_6;
                    seq_reg[7] <= seq_7;
                    seq_reg[8] <= seq_8;
                    seq_reg[9] <= seq_9;
                    seq_reg[10] <= seq_10;
                    seq_reg[11] <= seq_11;
                    seq_reg[12] <= seq_12;
                    seq_reg[13] <= seq_13;
                    seq_reg[14] <= seq_14;
                    seq_reg[15] <= seq_15;
                    seq_reg[16] <= seq_16;
                    seq_reg[17] <= seq_17;
                    seq_reg[18] <= seq_18;
                    seq_reg[19] <= seq_19;
                    p_reg <= p;
                    T <= ((p + 8'd39) >> 6) + 8'd1; // ceil(p/40) + 1
                    best_first_i <= 8'd21;
                    found <= 1'b0;
                    state <= INIT_SEARCH;
                end
                
                INIT_SEARCH: begin
                    n_reg <= 8'd1;
                    m_reg <= 8'd1;
                    a_reg <= 4'd0;
                    b_reg <= 4'd0;
                    c_reg <= 4'd0;
                    i <= 8'd0;
                    triple_count <= 8'd0;
                    first_i <= 8'd21;
                    candidate_valid <= 1'b1;
                    state <= SCANNING;
                end
                
                SCANNING: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= 8'd200) begin
                        state <= DONE;
                    end else if (i < p_reg) begin
                        // Check correlation condition
                        if (((seq_reg[i] == a_reg && (i + n_reg) < p_reg && seq_reg[i + n_reg] == b_reg && (i + n_reg + m_reg) < p_reg && seq_reg[i + n_reg + m_reg] != c_reg) ||
                             (seq_reg[i] == b_reg && (i + m_reg) < p_reg && seq_reg[i + m_reg] == c_reg && i >= n_reg && seq_reg[i - n_reg] != a_reg) ||
                             (seq_reg[i] == a_reg && (i + n_reg + m_reg) < p_reg && seq_reg[i + n_reg + m_reg] == c_reg && (i + n_reg) < p_reg && seq_reg[i + n_reg] != b_reg)) && candidate_valid) begin
                            candidate_valid <= 1'b0;
                            state <= NEXT_C;
                        end else begin
                            // Count triple occurrences
                            if ((i + n_reg) < p_reg && (i + n_reg + m_reg) < p_reg &&
                                seq_reg[i] == a_reg && seq_reg[i + n_reg] == b_reg && seq_reg[i + n_reg + m_reg] == c_reg) begin
                                triple_count <= triple_count + 8'd1;
                                if (first_i > 8'd20) begin
                                    first_i <= i;
                                end
                            end
                            i <= i + 8'd1;
                            if ((i + 8'd1) < p_reg) begin
                                state <= SCANNING;
                            end else begin
                                state <= EVALUATE;
                            end
                        end
                    end else begin
                        state <= EVALUATE;
                    end
                end
                
                EVALUATE: begin
                    if (candidate_valid && triple_count >= T) begin
                        if ((first_i < best_first_i) ||
                            (first_i == best_first_i && n_reg < best_n) ||
                            (first_i == best_first_i && n_reg == best_n && m_reg < best_m)) begin
                            best_a <= a_reg;
                            best_b <= b_reg;
                            best_c <= c_reg;
                            best_n <= n_reg;
                            best_m <= m_reg;
                            best_first_i <= first_i;
                        end
                    end
                    state <= NEXT_C;
                end
                
                NEXT_C: begin
                    if (c_reg == 4'd9) begin
                        state <= NEXT_B;
                    end else begin
                        c_reg <= c_reg + 4'd1;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= 8'd21;
                        candidate_valid <= 1'b1;
                        cycle_counter <= 8'd0;
                        state <= SCANNING;
                    end
                end
                
                NEXT_B: begin
                    if (b_reg == 4'd9) begin
                        state <= NEXT_A;
                    end else begin
                        b_reg <= b_reg + 4'd1;
                        c_reg <= 4'd0;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= 8'd21;
                        candidate_valid <= 1'b1;
                        cycle_counter <= 8'd0;
                        state <= SCANNING;
                    end
                end
                
                NEXT_A: begin
                    if (a_reg == 4'd9) begin
                        state <= NEXT_M;
                    end else begin
                        a_reg <= a_reg + 4'd1;
                        b_reg <= 4'd0;
                        c_reg <= 4'd0;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= 8'd21;
                        candidate_valid <= 1'b1;
                        cycle_counter <= 8'd0;
                        state <= SCANNING;
                    end
                end
                
                NEXT_M: begin
                    if (m_reg >= 8'd3) begin
                        state <= NEXT_N;
                    end else begin
                        m_reg <= m_reg + 8'd1;
                        a_reg <= 4'd0;
                        b_reg <= 4'd0;
                        c_reg <= 4'd0;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= 8'd21;
                        candidate_valid <= 1'b1;
                        cycle_counter <= 8'd0;
                        state <= SCANNING;
                    end
                end
                
                NEXT_N: begin
                    if (n_reg >= 8'd3) begin
                        state <= DONE;
                    end else begin
                        n_reg <= n_reg + 8'd1;
                        m_reg <= 8'd1;
                        a_reg <= 4'd0;
                        b_reg <= 4'd0;
                        c_reg <= 4'd0;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= 8'd21;
                        candidate_valid <= 1'b1;
                        cycle_counter <= 8'd0;
                        state <= SCANNING;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (best_first_i <= 8'd20) begin
                        found <= 1'b1;
                        a_out <= best_a;
                        b_out <= best_b;
                        c_out <= best_c;
                        n_out <= best_n;
                        m_out <= best_m;
                    end else begin
                        found <= 1'b0;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule