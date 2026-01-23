module bolt_pack_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] B,
    input wire [3:0] k,
    input wire [7:0] pack_sizes_0,
    input wire [7:0] pack_sizes_1,
    input wire [7:0] pack_sizes_2,
    input wire [7:0] pack_sizes_3,
    input wire [7:0] pack_sizes_4,
    input wire [7:0] pack_sizes_5,
    input wire [7:0] pack_sizes_6,
    input wire [7:0] pack_sizes_7,
    input wire [7:0] pack_sizes_8,
    input wire [7:0] pack_sizes_9,
    input wire [7:0] pack_sizes_10,
    input wire [7:0] pack_sizes_11,
    input wire [7:0] pack_sizes_12,
    input wire [7:0] pack_sizes_13,
    input wire [7:0] pack_sizes_14,
    input wire [7:0] pack_sizes_15,
    input wire [3:0] num_packs_0,
    input wire [3:0] num_packs_1,
    input wire [3:0] num_packs_2,
    input wire [3:0] num_packs_3,
    output reg [7:0] result,
    output reg done,
    output reg impossible
);

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_REAL = 4'd1;
    localparam [3:0] SETUP_DP = 4'd2;
    localparam [3:0] DP_LOOP = 4'd3;
    localparam [3:0] DP_UPDATE = 4'd4;
    localparam [3:0] FIND_MIN_SUM = 4'd5;
    localparam [3:0] STORE_RESULT = 4'd6;
    localparam [3:0] NEXT_PACK = 4'd7;
    localparam [3:0] NEXT_COMPANY = 4'd8;
    localparam [3:0] FIND_BEST = 4'd9;
    localparam [3:0] FINISHED = 4'd10;

    reg [3:0] state;
    reg [3:0] company_idx;
    reg [3:0] pack_idx;
    reg [9:0] sum_idx;
    reg [15:0] timeout;

    reg [7:0] dp [0:1023];
    reg [7:0] real_amounts [0:15];
    
    reg [7:0] prev_adv [0:3];
    reg [7:0] prev_real [0:3];
    reg [3:0] prev_num_packs;
    reg [3:0] prev_pack_idx;
    
    reg [7:0] current_real;
    reg [9:0] min_sum;
    reg [7:0] best_pack;
    reg best_found;
    reg [3:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            company_idx <= 4'd0;
            pack_idx <= 4'd0;
            sum_idx <= 10'd0;
            timeout <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            result <= 8'd0;
            best_pack <= 8'd255;
            best_found <= 1'b0;
            current_real <= 8'd0;
            min_sum <= 10'd0;
            prev_num_packs <= 4'd0;
            prev_pack_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    timeout <= 16'd0;
                    if (start) begin
                        state <= INIT_REAL;
                        company_idx <= 4'd0;
                        pack_idx <= 4'd0;
                    end
                end

                INIT_REAL: begin
                    if (pack_idx < num_packs_0) begin
                        case (pack_idx)
                            4'd0: real_amounts[0] <= pack_sizes_0;
                            4'd1: real_amounts[1] <= pack_sizes_1;
                            4'd2: real_amounts[2] <= pack_sizes_2;
                            4'd3: real_amounts[3] <= pack_sizes_3;
                            default: real_amounts[0] <= pack_sizes_0;
                        endcase
                        pack_idx <= pack_idx + 1;
                    end else begin
                        pack_idx <= 4'd0;
                        company_idx <= 4'd1;
                        if (k > 1) begin
                            state <= SETUP_DP;
                        end else begin
                            best_found <= 1'b0;
                            best_pack <= 8'd255;
                            state <= FIND_BEST;
                        end
                    end
                end

                SETUP_DP: begin
                    if (pack_idx < num_packs_{company_idx - 1}) begin
                        case (pack_idx)
                            4'd0: begin
                                case (company_idx - 1)
                                    4'd1: prev_adv[0] <= pack_sizes_4;
                                    4'd2: prev_adv[0] <= pack_sizes_8;
                                    4'd3: prev_adv[0] <= pack_sizes_12;
                                    default: prev_adv[0] <= 8'd0;
                                endcase
                                case (company_idx - 1)
                                    4'd1: prev_real[0] <= real_amounts[4];
                                    4'd2: prev_real[0] <= real_amounts[8];
                                    4'd3: prev_real[0] <= real_amounts[12];
                                    default: prev_real[0] <= 8'd0;
                                endcase
                            end
                            4'd1: begin
                                case (company_idx - 1)
                                    4'd1: prev_adv[1] <= pack_sizes_5;
                                    4'd2: prev_adv[1] <= pack_sizes_9;
                                    4'd3: prev_adv[1] <= pack_sizes_13;
                                    default: prev_adv[1] <= 8'd0;
                                endcase
                                case (company_idx - 1)
                                    4'd1: prev_real[1] <= real_amounts[5];
                                    4'd2: prev_real[1] <= real_amounts[9];
                                    4'd3: prev_real[1] <= real_amounts[13];
                                    default: prev_real[1] <= 8'd0;
                                endcase
                            end
                            4'd2: begin
                                case (company_idx - 1)
                                    4'd1: prev_adv[2] <= pack_sizes_6;
                                    4'd2: prev_adv[2] <= pack_sizes_10;
                                    4'd3: prev_adv[2] <= pack_sizes_14;
                                    default: prev_adv[2] <= 8'd0;
                                endcase
                                case (company_idx - 1)
                                    4'd1: prev_real[2] <= real_amounts[6];
                                    4'd2: prev_real[2] <= real_amounts[10];
                                    4'd3: prev_real[2] <= real_amounts[14];
                                    default: prev_real[2] <= 8'd0;
                                endcase
                            end
                            4'd3: begin
                                case (company_idx - 1)
                                    4'd1: prev_adv[3] <= pack_sizes_7;
                                    4'd2: prev_adv[3] <= pack_sizes_11;
                                    4'd3: prev_adv[3] <= pack_sizes_15;
                                    default: prev_adv[3] <= 8'd0;
                                endcase
                                case (company_idx - 1)
                                    4'd1: prev_real[3] <= real_amounts[7];
                                    4'd2: prev_real[3] <= real_amounts[11];
                                    4'd3: prev_real[3] <= real_amounts[15];
                                    default: prev_real[3] <= 8'd0;
                                endcase
                            end
                        endcase
                        pack_idx <= pack_idx + 1;
                    end else begin
                        case (company_idx - 1)
                            4'd0: prev_num_packs <= num_packs_0;
                            4'd1: prev_num_packs <= num_packs_1;
                            4'd2: prev_num_packs <= num_packs_2;
                            4'd3: prev_num_packs <= num_packs_3;
                            default: prev_num_packs <= 4'd0;
                        endcase
                        pack_idx <= 4'd0;
                        prev_pack_idx <= 4'd0;
                        dp[0] <= 8'd0;
                        for (i = 4'd1; i < 4'd10; i = i + 1) begin
                            dp[i] <= 8'd255;
                        end
                        for (i = 10'd10; i < 10'd1024; i = i + 1) begin
                            dp[i] <= 8'd255;
                        end
                        state <= DP_LOOP;
                    end
                end

                DP_LOOP: begin
                    if (prev_pack_idx < prev_num_packs) begin
                        sum_idx <= prev_adv[prev_pack_idx];
                        state <= DP_UPDATE;
                    end else begin
                        prev_pack_idx <= 4'd0;
                        sum_idx <= 10'd0;
                        state <= FIND_MIN_SUM;
                    end
                end

                DP_UPDATE: begin
                    if (sum_idx < 10'd1024) begin
                        if (dp[sum_idx - prev_adv[prev_pack_idx]] != 8'd255) begin
                            if (dp[sum_idx] > dp[sum_idx - prev_adv[prev_pack_idx]] + prev_real[prev_pack_idx]) begin
                                dp[sum_idx] <= dp[sum_idx - prev_adv[prev_pack_idx]] + prev_real[prev_pack_idx];
                            end
                        end
                        sum_idx <= sum_idx + 1;
                    end else begin
                        prev_pack_idx <= prev_pack_idx + 1;
                        state <= DP_LOOP;
                    end
                end

                FIND_MIN_SUM: begin
                    if (sum_idx < 10'd1024) begin
                        if (sum_idx >= pack_sizes_{company_idx * 4 + pack_idx}) begin
                            if (dp[sum_idx] != 8'd255) begin
                                min_sum <= sum_idx;
                                current_real <= dp[sum_idx];
                                state <= STORE_RESULT;
                            end else begin
                                sum_idx <= sum_idx + 1;
                            end
                        end else begin
                            sum_idx <= sum_idx + 1;
                        end
                    end else begin
                        current_real <= 8'd255;
                        state <= STORE_RESULT;
                    end
                end

                STORE_RESULT: begin
                    real_amounts[company_idx * 4 + pack_idx] <= current_real;
                    state <= NEXT_PACK;
                end

                NEXT_PACK: begin
                    pack_idx <= pack_idx + 1;
                    if (pack_idx + 1 < num_packs_{company_idx}) begin
                        state <= SETUP_DP;
                    end else begin
                        pack_idx <= 4'd0;
                        state <= NEXT_COMPANY;
                    end
                end

                NEXT_COMPANY: begin
                    company_idx <= company_idx + 1;
                    if (company_idx < k - 1) begin
                        state <= SETUP_DP;
                    end else begin
                        best_found <= 1'b0;
                        best_pack <= 8'd255;
                        state <= FIND_BEST;
                    end
                end

                FIND_BEST: begin
                    if (company_idx < k) begin
                        if (pack_idx < num_packs_{company_idx}) begin
                            if (real_amounts[company_idx * 4 + pack_idx] >= B) begin
                                if (!best_found || pack_sizes_{company_idx * 4 + pack_idx} < best_pack) begin
                                    best_pack <= pack_sizes_{company_idx * 4 + pack_idx};
                                    best_found <= 1'b1;
                                end
                            end
                            pack_idx <= pack_idx + 1;
                        end else begin
                            pack_idx <= 4'd0;
                            company_idx <= company_idx + 1;
                        end
                    end else begin
                        if (best_found) begin
                            result <= best_pack;
                            impossible <= 1'b0;
                        end else begin
                            result <= 8'd0;
                            impossible <= 1'b1;
                        end
                        done <= 1'b1;
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    if (!start) begin
                        state <= FINISHED;
                    end else begin
                        state <= FINISHED;
                    end
                end

                default: state <= IDLE;
            endcase

            if (state != IDLE && state != FINISHED) begin
                if (timeout >= 16'd5000) begin
                    impossible <= 1'b1;
                    done <= 1'b1;
                    state <= FINISHED;
                end else begin
                    timeout <= timeout + 1;
                end
            end else begin
                timeout <= 16'd0;
            end
        end
    end
endmodule