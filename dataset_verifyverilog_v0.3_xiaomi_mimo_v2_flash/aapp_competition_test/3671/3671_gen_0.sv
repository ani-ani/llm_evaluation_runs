module JobScheduler (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [15:0] times_0,
    input wire [15:0] times_1,
    input wire [15:0] times_2,
    input wire [15:0] times_3,
    input wire [15:0] times_4,
    input wire [15:0] times_5,
    input wire [15:0] times_6,
    input wire [15:0] times_7,
    output reg [5:0] result,
    output reg done
);

localparam [2:0] S_IDLE = 3'd0;
localparam [2:0] S_SET_I = 3'd1;
localparam [2:0] S_FIND_J = 3'd2;
localparam [2:0] S_NEXT_L = 3'd3;
localparam [2:0] S_UPDATE_DP = 3'd4;

reg [2:0] state;
reg [2:0] next_state;
reg [2:0] i;
reg [1:0] L_state;
reg [2:0] j;
reg [5:0] dp_0;
reg [5:0] dp_1;
reg [5:0] dp_2;
reg [5:0] dp_3;
reg [5:0] dp_4;
reg [5:0] dp_5;
reg [5:0] dp_6;
reg [5:0] dp_7;
reg [15:0] time_i;
reg [16:0] add_val;
reg [5:0] candidate_max;
reg [5:0] candidate;
reg [5:0] dp_next;
reg [2:0] j_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        result <= 6'd0;
        i <= 3'd0;
        L_state <= 2'd0;
        j <= 3'd0;
        time_i <= 16'd0;
        add_val <= 17'd0;
        candidate_max <= 6'd0;
        candidate <= 6'd0;
        dp_next <= 6'd0;
        dp_0 <= 6'd0;
        dp_1 <= 6'd0;
        dp_2 <= 6'd0;
        dp_3 <= 6'd0;
        dp_4 <= 6'd0;
        dp_5 <= 6'd0;
        dp_6 <= 6'd0;
        dp_7 <= 6'd0;
        j_reg <= 3'd0;
    end else begin
        state <= next_state;
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    if (N > 4'd0) begin
                        i <= N - 4'd1;
                    end else begin
                        i <= 3'd0;
                    end
                    dp_next <= 6'd0;
                end
            end
            S_SET_I: begin
                if (i == 3'd0) time_i <= times_0;
                else if (i == 3'd1) time_i <= times_1;
                else if (i == 3'd2) time_i <= times_2;
                else if (i == 3'd3) time_i <= times_3;
                else if (i == 3'd4) time_i <= times_4;
                else if (i == 3'd5) time_i <= times_5;
                else if (i == 3'd6) time_i <= times_6;
                else time_i <= times_7;
                candidate_max <= dp_next;
                L_state <= 2'd0;
                j <= i + 3'd1;
                j_reg <= i + 3'd1;
            end
            S_FIND_J: begin
                add_val <= time_i + {13'd0, (2 + L_state)};
                if (j_reg < N) begin
                    if (j_reg == 3'd0) begin
                        if ({1'b0, times_0} >= add_val) begin
                            candidate <= (2 + L_state) + dp_0;
                        end else begin
                            candidate <= 6'd0;
                        end
                    end else if (j_reg == 3'd1) begin
                        if ({1'b0, times_1} >= add_val) begin
                            candidate <= (2 + L_state) + dp_1;
                        end else begin
                            candidate <= 6'd0;
                        end
                    end else if (j_reg == 3'd2) begin
                        if ({1'b0, times_2} >= add_val) begin
                            candidate <= (2 + L_state) + dp_2;
                        end else begin
                            candidate <= 6'd0;
                        end
                    end else if (j_reg == 3'd3) begin
                        if ({1'b0, times_3} >= add_val) begin
                            candidate <= (2 + L_state) + dp_3;
                        end else begin
                            candidate <= 6'd0;
                        end
                    end else if (j_reg == 3'd4) begin
                        if ({1'b0, times_4} >= add_val) begin
                            candidate <= (2 + L_state) + dp_4;
                        end else begin
                            candidate <= 6'd0;
                        end
                    end else if (j_reg == 3'd5) begin
                        if ({1'b0, times_5} >= add_val) begin
                            candidate <= (2 + L_state) + dp_5;
                        end else begin
                            candidate <= 6'd0;
                        end
                    end else if (j_reg == 3'd6) begin
                        if ({1'b0, times_6} >= add_val) begin
                            candidate <= (2 + L_state) + dp_6;
                        end else begin
                            candidate <= 6'd0;
                        end
                    end else begin
                        if ({1'b0, times_7} >= add_val) begin
                            candidate <= (2 + L_state) + dp_7;
                        end else begin
                            candidate <= 6'd0;
                        end
                    end
                end else begin
                    candidate <= (2 + L_state);
                end
            end
            S_NEXT_L: begin
                if (candidate > candidate_max) begin
                    candidate_max <= candidate;
                end
                if (L_state == 2'd2) begin
                    if (i == 3'd0) dp_0 <= candidate_max;
                    else if (i == 3'd1) dp_1 <= candidate_max;
                    else if (i == 3'd2) dp_2 <= candidate_max;
                    else if (i == 3'd3) dp_3 <= candidate_max;
                    else if (i == 3'd4) dp_4 <= candidate_max;
                    else if (i == 3'd5) dp_5 <= candidate_max;
                    else if (i == 3'd6) dp_6 <= candidate_max;
                    else dp_7 <= candidate_max;
                    dp_next <= candidate_max;
                end
            end
            S_UPDATE_DP: begin
                if (i == 3'd0) begin
                    result <= candidate_max;
                    done <= 1'b1;
                end
            end
        endcase
    end
end

always @(*) begin
    next_state = state;
    case (state)
        S_IDLE: begin
            if (start) next_state = S_SET_I;
            else next_state = S_IDLE;
        end
        S_SET_I: begin
            next_state = S_FIND_J;
        end
        S_FIND_J: begin
            if (j_reg < N) begin
                if (j_reg == 3'd0) begin
                    if ({1'b0, times_0} >= add_val) next_state = S_NEXT_L;
                    else next_state = S_FIND_J;
                end else if (j_reg == 3'd1) begin
                    if ({1'b0, times_1} >= add_val) next_state = S_NEXT_L;
                    else next_state = S_FIND_J;
                end else if (j_reg == 3'd2) begin
                    if ({1'b0, times_2} >= add_val) next_state = S_NEXT_L;
                    else next_state = S_FIND_J;
                end else if (j_reg == 3'd3) begin
                    if ({1'b0, times_3} >= add_val) next_state = S_NEXT_L;
                    else next_state = S_FIND_J;
                end else if (j_reg == 3'd4) begin
                    if ({1'b0, times_4} >= add_val) next_state = S_NEXT_L;
                    else next_state = S_FIND_J;
                end else if (j_reg == 3'd5) begin
                    if ({1'b0, times_5} >= add_val) next_state = S_NEXT_L;
                    else next_state = S_FIND_J;
                end else if (j_reg == 3'd6) begin
                    if ({1'b0, times_6} >= add_val) next_state = S_NEXT_L;
                    else next_state = S_FIND_J;
                end else begin
                    if ({1'b0, times_7} >= add_val) next_state = S_NEXT_L;
                    else next_state = S_FIND_J;
                end
            end else begin
                next_state = S_NEXT_L;
            end
        end
        S_NEXT_L: begin
            if (L_state == 2'd2) next_state = S_UPDATE_DP;
            else next_state = S_FIND_J;
        end
        S_UPDATE_DP: begin
            if (i == 3'd0) next_state = S_IDLE;
            else next_state = S_SET_I;
        end
        default: next_state = S_IDLE;
    endcase
end

endmodule