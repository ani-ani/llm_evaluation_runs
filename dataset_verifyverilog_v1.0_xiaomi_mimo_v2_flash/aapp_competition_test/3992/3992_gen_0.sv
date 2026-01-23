module chocolate_division (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SUM = 3'd1;
    localparam [2:0] CHECK_S = 3'd2;
    localparam [2:0] FACTORIZE = 3'd3;
    localparam [2:0] COMPUTE_COST = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Registers
    reg [2:0] state;
    reg [15:0] S;
    reg [7:0] a_reg_0, a_reg_1, a_reg_2, a_reg_3, a_reg_4, a_reg_5, a_reg_6, a_reg_7;
    reg [4:0] prime_index;
    reg [15:0] min_cost;
    reg [15:0] current_cost;
    reg [7:0] current_p;
    reg [7:0] current_residue;
    reg [3:0] i;
    reg [15:0] temp_sum;
    reg [7:0] remainder_reg;
    reg [15:0] divisor_reg;
    reg [3:0] mod_remainder;
    reg is_prime_flag;
    reg [3:0] cycle_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            S <= 16'd0;
            min_cost <= 16'hFFFF;
            a_reg_0 <= 8'd0;
            a_reg_1 <= 8'd0;
            a_reg_2 <= 8'd0;
            a_reg_3 <= 8'd0;
            a_reg_4 <= 8'd0;
            a_reg_5 <= 8'd0;
            a_reg_6 <= 8'd0;
            a_reg_7 <= 8'd0;
            prime_index <= 5'd0;
            current_cost <= 16'd0;
            current_p <= 8'd0;
            current_residue <= 8'd0;
            i <= 4'd0;
            temp_sum <= 16'd0;
            remainder_reg <= 8'd0;
            divisor_reg <= 16'd0;
            mod_remainder <= 4'd0;
            is_prime_flag <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        a_reg_0 <= arr_0;
                        a_reg_1 <= arr_1;
                        a_reg_2 <= arr_2;
                        a_reg_3 <= arr_3;
                        a_reg_4 <= arr_4;
                        a_reg_5 <= arr_5;
                        a_reg_6 <= arr_6;
                        a_reg_7 <= arr_7;
                        temp_sum <= 16'd0;
                        i <= 4'd0;
                        state <= SUM;
                    end
                end

                SUM: begin
                    if (i < n) begin
                        case (i)
                            4'd0: temp_sum <= temp_sum + {8'd0, a_reg_0};
                            4'd1: temp_sum <= temp_sum + {8'd0, a_reg_1};
                            4'd2: temp_sum <= temp_sum + {8'd0, a_reg_2};
                            4'd3: temp_sum <= temp_sum + {8'd0, a_reg_3};
                            4'd4: temp_sum <= temp_sum + {8'd0, a_reg_4};
                            4'd5: temp_sum <= temp_sum + {8'd0, a_reg_5};
                            4'd6: temp_sum <= temp_sum + {8'd0, a_reg_6};
                            4'd7: temp_sum <= temp_sum + {8'd0, a_reg_7};
                            default: temp_sum <= temp_sum;
                        endcase
                        i <= i + 4'd1;
                    end else begin
                        S <= temp_sum;
                        state <= CHECK_S;
                    end
                end

                CHECK_S: begin
                    if (S == 16'd1) begin
                        result <= 16'hFFFF;
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        prime_index <= 5'd0;
                        min_cost <= 16'hFFFF;
                        cycle_count <= 4'd0;
                        state <= FACTORIZE;
                    end
                end

                FACTORIZE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (cycle_count >= 4'd15) begin
                        // Timeout protection
                        result <= 16'hFFFF;
                        done <= 1'b1;
                        state <= DONE;
                    end else if (prime_index < 5'd8) begin
                        case (prime_index)
                            5'd0: current_p <= 8'd2;
                            5'd1: current_p <= 8'd3;
                            5'd2: current_p <= 8'd5;
                            5'd3: current_p <= 8'd7;
                            5'd4: current_p <= 8'd11;
                            5'd5: current_p <= 8'd13;
                            5'd6: current_p <= 8'd17;
                            5'd7: current_p <= 8'd19;
                            default: current_p <= 8'd2;
                        endcase
                        // Check if current_p divides S
                        case (prime_index)
                            5'd0: if (S % 8'd2 == 16'd0) is_prime_flag <= 1'b1; else is_prime_flag <= 1'b0;
                            5'd1: if (S % 8'd3 == 16'd0) is_prime_flag <= 1'b1; else is_prime_flag <= 1'b0;
                            5'd2: if (S % 8'd5 == 16'd0) is_prime_flag <= 1'b1; else is_prime_flag <= 1'b0;
                            5'd3: if (S % 8'd7 == 16'd0) is_prime_flag <= 1'b1; else is_prime_flag <= 1'b0;
                            5'd4: if (S % 8'd11 == 16'd0) is_prime_flag <= 1'b1; else is_prime_flag <= 1'b0;
                            5'd5: if (S % 8'd13 == 16'd0) is_prime_flag <= 1'b1; else is_prime_flag <= 1'b0;
                            5'd6: if (S % 8'd17 == 16'd0) is_prime_flag <= 1'b1; else is_prime_flag <= 1'b0;
                            5'd7: if (S % 8'd19 == 16'd0) is_prime_flag <= 1'b1; else is_prime_flag <= 1'b0;
                            default: is_prime_flag <= 1'b0;
                        endcase
                        if (is_prime_flag) begin
                            current_cost <= 16'd0;
                            current_residue <= 8'd0;
                            i <= 4'd0;
                            state <= COMPUTE_COST;
                        end else begin
                            prime_index <= prime_index + 5'd1;
                        end
                    end else begin
                        // Check if S itself is a prime > 19
                        if (S > 19 && S % 8'd2 != 0 && S % 8'd3 != 0 && S % 8'd5 != 0 && S % 8'd7 != 0 && S % 8'd11 != 0 && S % 8'd13 != 0 && S % 8'd17 != 0 && S % 8'd19 != 0) begin
                            current_p <= S[7:0];
                            current_cost <= 16'd0;
                            current_residue <= 8'd0;
                            i <= 4'd0;
                            state <= COMPUTE_COST;
                        end else begin
                            result <= min_cost;
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                COMPUTE_COST: begin
                    if (i < n) begin
                        // Get current value
                        case (i)
                            4'd0: begin
                                remainder_reg <= a_reg_0 % current_p;
                                divisor_reg <= {8'd0, current_p};
                            end
                            4'd1: begin
                                remainder_reg <= a_reg_1 % current_p;
                                divisor_reg <= {8'd0, current_p};
                            end
                            4'd2: begin
                                remainder_reg <= a_reg_2 % current_p;
                                divisor_reg <= {8'd0, current_p};
                            end
                            4'd3: begin
                                remainder_reg <= a_reg_3 % current_p;
                                divisor_reg <= {8'd0, current_p};
                            end
                            4'd4: begin
                                remainder_reg <= a_reg_4 % current_p;
                                divisor_reg <= {8'd0, current_p};
                            end
                            4'd5: begin
                                remainder_reg <= a_reg_5 % current_p;
                                divisor_reg <= {8'd0, current_p};
                            end
                            4'd6: begin
                                remainder_reg <= a_reg_6 % current_p;
                                divisor_reg <= {8'd0, current_p};
                            end
                            4'd7: begin
                                remainder_reg <= a_reg_7 % current_p;
                                divisor_reg <= {8'd0, current_p};
                            end
                            default: begin
                                remainder_reg <= 8'd0;
                                divisor_reg <= 16'd0;
                            end
                        endcase
                        i <= i + 4'd1;
                    end else begin
                        if (current_cost < min_cost) begin
                            min_cost <= current_cost;
                        end
                        prime_index <= prime_index + 5'd1;
                        state <= FACTORIZE;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Update residue and cost in COMPUTE_COST state
            if (state == COMPUTE_COST && i > 4'd0 && i <= n) begin
                // Update residue: (current_residue + remainder) % current_p
                if (current_residue + remainder_reg >= current_p) begin
                    current_residue <= current_residue + remainder_reg - current_p;
                end else begin
                    current_residue <= current_residue + remainder_reg;
                end
                // Add cost
                if (current_residue <= (current_p >> 1)) begin
                    current_cost <= current_cost + {8'd0, current_residue};
                end else begin
                    current_cost <= current_cost + {8'd0, (current_p - current_residue)};
                end
            end
        end
    end
endmodule