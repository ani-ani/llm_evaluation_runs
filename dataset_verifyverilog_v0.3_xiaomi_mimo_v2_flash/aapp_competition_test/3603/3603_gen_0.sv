module LanguagePairing (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    input wire [3:0] lang1_0,
    input wire [3:0] lang2_0,
    input wire [3:0] lang1_1,
    input wire [3:0] lang2_1,
    input wire [3:0] lang1_2,
    input wire [3:0] lang2_2,
    input wire [3:0] lang1_3,
    input wire [3:0] lang2_3,
    output reg [3:0] pair1_tr1,
    output reg [3:0] pair1_tr2,
    output reg [3:0] pair2_tr1,
    output reg [3:0] pair2_tr2,
    output reg valid,
    output reg impossible
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] CHECK_M    = 4'd1;
    localparam [3:0] M2_CHECK   = 4'd2;
    localparam [3:0] M4_CHECK1  = 4'd3;
    localparam [3:0] M4_CHECK2  = 4'd4;
    localparam [3:0] M4_CHECK3  = 4'd5;
    localparam [3:0] ODD_M      = 4'd6;
    localparam [3:0] FINISH     = 4'd7;

    reg [3:0] state, next_state;
    reg [3:0] m4_phase;  // Tracks which pairing to check for M=4

    // Helper function to check if two translators share a language
    function automatic logic share_language(
        input [3:0] a1, a2,
        input [3:0] b1, b2
    );
        share_language = (a1 == b1) || (a1 == b2) || (a2 == b1) || (a2 == b2);
    endfunction

    // Combinational signals for share checks
    logic m2_share;
    logic pair1_share_1, pair2_share_1;
    logic pair1_share_2, pair2_share_2;
    logic pair1_share_3, pair2_share_3;

    always_comb begin
        m2_share = share_language(lang1_0, lang2_0, lang1_1, lang2_1);
        pair1_share_1 = share_language(lang1_0, lang2_0, lang1_1, lang2_1);
        pair2_share_1 = share_language(lang1_2, lang2_2, lang1_3, lang2_3);
        pair1_share_2 = share_language(lang1_0, lang2_0, lang1_2, lang2_2);
        pair2_share_2 = share_language(lang1_1, lang2_1, lang1_3, lang2_3);
        pair1_share_3 = share_language(lang1_0, lang2_0, lang1_3, lang2_3);
        pair2_share_3 = share_language(lang1_1, lang2_1, lang1_2, lang2_2);
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            m4_phase <= 4'd0;
            valid <= 1'b0;
            impossible <= 1'b0;
            pair1_tr1 <= 4'd0;
            pair1_tr2 <= 4'd0;
            pair2_tr1 <= 4'd0;
            pair2_tr2 <= 4'd0;
        end else begin
            state <= next_state;
            
            // Default assignments
            if (state == IDLE) begin
                valid <= 1'b0;
                impossible <= 1'b0;
                m4_phase <= 4'd0;
            end

            case (state)
                M2_CHECK: begin
                    if (m2_share) begin
                        pair1_tr1 <= 4'd0;
                        pair1_tr2 <= 4'd1;
                        valid <= 1'b1;
                    end else begin
                        impossible <= 1'b1;
                    end
                end
                
                M4_CHECK1: begin
                    if (pair1_share_1 && pair2_share_1) begin
                        pair1_tr1 <= 4'd0;
                        pair1_tr2 <= 4'd1;
                        pair2_tr1 <= 4'd2;
                        pair2_tr2 <= 4'd3;
                        valid <= 1'b1;
                    end
                end
                
                M4_CHECK2: begin
                    if (pair1_share_2 && pair2_share_2) begin
                        pair1_tr1 <= 4'd0;
                        pair1_tr2 <= 4'd2;
                        pair2_tr1 <= 4'd1;
                        pair2_tr2 <= 4'd3;
                        valid <= 1'b1;
                    end
                end
                
                M4_CHECK3: begin
                    if (pair1_share_3 && pair2_share_3) begin
                        pair1_tr1 <= 4'd0;
                        pair1_tr2 <= 4'd3;
                        pair2_tr1 <= 4'd1;
                        pair2_tr2 <= 4'd2;
                        valid <= 1'b1;
                    end else begin
                        impossible <= 1'b1;
                    end
                end
                
                ODD_M: begin
                    impossible <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_M;
            end
            
            CHECK_M: begin
                if (M[0]) // M is odd
                    next_state = ODD_M;
                else if (M == 4'd2)
                    next_state = M2_CHECK;
                else if (M == 4'd4)
                    next_state = M4_CHECK1;
                else
                    next_state = ODD_M; // Unsupported M > 4 or M=0
            end
            
            M2_CHECK: next_state = FINISH;
            
            M4_CHECK1: begin
                if (pair1_share_1 && pair2_share_1)
                    next_state = FINISH;
                else
                    next_state = M4_CHECK2;
            end
            
            M4_CHECK2: begin
                if (pair1_share_2 && pair2_share_2)
                    next_state = FINISH;
                else
                    next_state = M4_CHECK3;
            end
            
            M4_CHECK3: begin
                if (pair1_share_3 && pair2_share_3)
                    next_state = FINISH;
                else
                    next_state = FINISH;
            end
            
            ODD_M: next_state = FINISH;
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

endmodule