module triple_correlation #(
    parameter P_MAX = 20,
    parameter N_MAX = 3,
    parameter M_MAX = 3
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] p,
    input wire [3:0] seq [0:P_MAX-1],
    output reg found,
    output reg [3:0] a_out,
    output reg [3:0] b_out,
    output reg [3:0] c_out,
    output reg [7:0] n_out,
    output reg [7:0] m_out,
    output reg done
);

    // Internal registers
    reg [3:0] seq_reg [0:P_MAX-1];
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
    integer idx; // For loop variable

    // State declaration
    localparam [3:0]
        IDLE     = 4'd0,
        LOAD     = 4'd1,
        SEARCH   = 4'd2,
        SCANNING = 4'd3,
        EVALUATE = 4'd4,
        NEXT_C   = 4'd5,
        NEXT_B   = 4'd6,
        NEXT_A   = 4'd7,
        NEXT_M   = 4'd8,
        NEXT_N   = 4'd9,
        DONE     = 4'd10;
    
    reg [3:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
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
            first_i <= P_MAX + 8'd1;
            candidate_valid <= 1'b0;
            best_a <= 4'd0;
            best_b <= 4'd0;
            best_c <= 4'd0;
            best_n <= 8'd0;
            best_m <= 8'd0;
            best_first_i <= P_MAX + 8'd1;
            for (idx = 0; idx < P_MAX; idx = idx + 1) begin
                seq_reg[idx] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    if (start) begin
                        p_reg <= p;
                        T <= (p + 8'd39) / 8'd40 + 8'd1;
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    for (idx = 0; idx < P_MAX; idx = idx + 1) begin
                        seq_reg[idx] <= seq[idx];
                    end
                    best_first_i <= P_MAX + 8'd1;
                    state <= SEARCH;
                end
                
                SEARCH: begin
                    n_reg <= 8'd1;
                    m_reg <= 8'd1;
                    a_reg <= 4'd0;
                    b_reg <= 4'd0;
                    c_reg <= 4'd0;
                    state <= SCANNING;
                    i <= 8'd0;
                    triple_count <= 8'd0;
                    first_i <= P_MAX + 8'd1;
                    candidate_valid <= 1'b1;
                end
                
                SCANNING: begin
                    if (i < p_reg) begin
                        if ( (
                            (seq_reg[i] == a_reg && i + n_reg < p_reg && seq_reg[i + n_reg] == b_reg && i + n_reg + m_reg < p_reg && seq_reg[i + n_reg + m_reg] != c_reg) ||
                            (seq_reg[i] == b_reg && i + m_reg < p_reg && seq_reg[i + m_reg] == c_reg && i >= n_reg && seq_reg[i - n_reg] != a_reg) ||
                            (seq_reg[i] == a_reg && i + n_reg + m_reg < p_reg && seq_reg[i + n_reg + m_reg] == c_reg && i + n_reg < p_reg && seq_reg[i + n_reg] != b_reg)
                        )) begin
                            candidate_valid <= 1'b0;
                            state <= NEXT_C;
                        end else begin
                            if (i + n_reg < p_reg && i + n_reg + m_reg < p_reg &&
                                seq_reg[i] == a_reg && seq_reg[i + n_reg] == b_reg && seq_reg[i + n_reg + m_reg] == c_reg) begin
                                triple_count <= triple_count + 8'd1;
                                if (first_i > P_MAX) first_i <= i;
                            end
                            i <= i + 8'd1;
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
                        state <= SCANNING;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= P_MAX + 8'd1;
                        candidate_valid <= 1'b1;
                    end
                end
                
                NEXT_B: begin
                    if (b_reg == 4'd9) begin
                        state <= NEXT_A;
                    end else begin
                        b_reg <= b_reg + 4'd1;
                        c_reg <= 4'd0;
                        state <= SCANNING;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= P_MAX + 8'd1;
                        candidate_valid <= 1'b1;
                    end
                end
                
                NEXT_A: begin
                    if (a_reg == 4'd9) begin
                        state <= NEXT_M;
                    end else begin
                        a_reg <= a_reg + 4'd1;
                        b_reg <= 4'd0;
                        c_reg <= 4'd0;
                        state <= SCANNING;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= P_MAX + 8'd1;
                        candidate_valid <= 1'b1;
                    end
                end
                
                NEXT_M: begin
                    if (m_reg == M_MAX) begin
                        state <= NEXT_N;
                    end else begin
                        m_reg <= m_reg + 8'd1;
                        a_reg <= 4'd0;
                        b_reg <= 4'd0;
                        c_reg <= 4'd0;
                        state <= SCANNING;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= P_MAX + 8'd1;
                        candidate_valid <= 1'b1;
                    end
                end
                
                NEXT_N: begin
                    if (n_reg == N_MAX) begin
                        state <= DONE;
                    end else begin
                        n_reg <= n_reg + 8'd1;
                        m_reg <= 8'd1;
                        a_reg <= 4'd0;
                        b_reg <= 4'd0;
                        c_reg <= 4'd0;
                        state <= SCANNING;
                        i <= 8'd0;
                        triple_count <= 8'd0;
                        first_i <= P_MAX + 8'd1;
                        candidate_valid <= 1'b1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (best_first_i <= P_MAX) begin
                        found <= 1'b1;
                        a_out <= best_a;
                        b_out <= best_b;
                        c_out <= best_c;
                        n_out <= best_n;
                        m_out <= best_m;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule