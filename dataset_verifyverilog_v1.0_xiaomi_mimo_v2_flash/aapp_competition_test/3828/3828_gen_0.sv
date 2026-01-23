module sorted_train (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] p0,
    input [7:0] p1,
    input [7:0] p2,
    input [7:0] p3,
    input [7:0] p4,
    input [7:0] p5,
    input [7:0] p6,
    input [7:0] p7,
    input [7:0] p8,
    input [7:0] p9,
    input [7:0] p10,
    input [7:0] p11,
    input [7:0] p12,
    input [7:0] p13,
    input [7:0] p14,
    input [7:0] p15,
    output reg [7:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] BUILD   = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    localparam [2:0] INIT    = 3'd4;
    
    reg [2:0] state, next_state;
    reg [7:0] j, k;
    reg [7:0] current_len, max_len;
    reg [7:0] inv0, inv1, inv2, inv3, inv4, inv5, inv6, inv7;
    reg [7:0] inv8, inv9, inv10, inv11, inv12, inv13, inv14, inv15;
    reg [7:0] p_reg [0:15];
    
    integer i;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start && n > 0) ? INIT : IDLE;
            INIT: next_state = BUILD;
            BUILD: next_state = (j >= n) ? COMPUTE : BUILD;
            COMPUTE: next_state = (k >= n) ? DONE : COMPUTE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            j <= 8'd0;
            k <= 8'd0;
            current_len <= 8'd0;
            max_len <= 8'd0;
            // Initialize inv array
            inv0 <= 8'd0; inv1 <= 8'd0; inv2 <= 8'd0; inv3 <= 8'd0;
            inv4 <= 8'd0; inv5 <= 8'd0; inv6 <= 8'd0; inv7 <= 8'd0;
            inv8 <= 8'd0; inv9 <= 8'd0; inv10 <= 8'd0; inv11 <= 8'd0;
            inv12 <= 8'd0; inv13 <= 8'd0; inv14 <= 8'd0; inv15 <= 8'd0;
            // Initialize p_reg
            p_reg[0] <= 8'd0; p_reg[1] <= 8'd0; p_reg[2] <= 8'd0; p_reg[3] <= 8'd0;
            p_reg[4] <= 8'd0; p_reg[5] <= 8'd0; p_reg[6] <= 8'd0; p_reg[7] <= 8'd0;
            p_reg[8] <= 8'd0; p_reg[9] <= 8'd0; p_reg[10] <= 8'd0; p_reg[11] <= 8'd0;
            p_reg[12] <= 8'd0; p_reg[13] <= 8'd0; p_reg[14] <= 8'd0; p_reg[15] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && n > 0) begin
                        // Capture input array
                        p_reg[0] <= p0;
                        p_reg[1] <= p1;
                        p_reg[2] <= p2;
                        p_reg[3] <= p3;
                        p_reg[4] <= p4;
                        p_reg[5] <= p5;
                        p_reg[6] <= p6;
                        p_reg[7] <= p7;
                        p_reg[8] <= p8;
                        p_reg[9] <= p9;
                        p_reg[10] <= p10;
                        p_reg[11] <= p11;
                        p_reg[12] <= p12;
                        p_reg[13] <= p13;
                        p_reg[14] <= p14;
                        p_reg[15] <= p15;
                    end
                end
                
                INIT: begin
                    j <= 8'd0;
                end
                
                BUILD: begin
                    if (j < n) begin
                        // inv[p[j]-1] <= j
                        case (p_reg[j])
                            8'd1: inv0 <= j;
                            8'd2: inv1 <= j;
                            8'd3: inv2 <= j;
                            8'd4: inv3 <= j;
                            8'd5: inv4 <= j;
                            8'd6: inv5 <= j;
                            8'd7: inv6 <= j;
                            8'd8: inv7 <= j;
                            8'd9: inv8 <= j;
                            8'd10: inv9 <= j;
                            8'd11: inv10 <= j;
                            8'd12: inv11 <= j;
                            8'd13: inv12 <= j;
                            8'd14: inv13 <= j;
                            8'd15: inv14 <= j;
                            8'd16: inv15 <= j;
                            default: begin end
                        endcase
                        j <= j + 8'd1;
                    end
                end
                
                COMPUTE: begin
                    if (k < n) begin
                        if (k > 0) begin
                            // Get inv[k-1]
                            case (k)
                                8'd1: begin
                                    if (inv0 > ((k == 8'd1) ? 8'd0 : inv1)) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd2: begin
                                    if (inv1 > inv0) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd3: begin
                                    if (inv2 > inv1) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd4: begin
                                    if (inv3 > inv2) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd5: begin
                                    if (inv4 > inv3) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd6: begin
                                    if (inv5 > inv4) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd7: begin
                                    if (inv6 > inv5) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd8: begin
                                    if (inv7 > inv6) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd9: begin
                                    if (inv8 > inv7) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd10: begin
                                    if (inv9 > inv8) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd11: begin
                                    if (inv10 > inv9) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd12: begin
                                    if (inv11 > inv10) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd13: begin
                                    if (inv12 > inv11) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd14: begin
                                    if (inv13 > inv12) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd15: begin
                                    if (inv14 > inv13) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                8'd16: begin
                                    if (inv15 > inv14) begin
                                        current_len <= current_len + 8'd1;
                                        if (current_len + 8'd1 > max_len)
                                            max_len <= current_len + 8'd1;
                                    end else begin
                                        current_len <= 8'd1;
                                    end
                                end
                                default: current_len <= 8'd1;
                            endcase
                        end else begin
                            // k == 1, first iteration
                            current_len <= 8'd1;
                            max_len <= 8'd1;
                        end
                        k <= k + 8'd1;
                    end
                end
                
                DONE: begin
                    // n - max_len
                    result <= n - max_len;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule