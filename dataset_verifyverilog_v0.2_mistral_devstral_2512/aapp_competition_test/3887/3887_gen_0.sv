module rebus_solver (
    input clk,
    input rst_n,
    input start,
    input [1999:0] char_in,
    input [7:0] n_in,
    output reg result_valid,
    output reg is_possible,
    output reg [10:0][7:0] sol_vals,
    output reg [10:0] sol_signs,
    output reg [3:0] num_terms
);

    parameter MAX_TERMS = 11;
    parameter IDLE = 3'b000;
    parameter PARSE = 3'b001;
    parameter SOLVE = 3'b010;
    parameter OUTPUT = 3'b100;

    reg [2:0] state;
    reg [3:0] term_count;
    reg [7:0] target_n;
    reg [10:0] term_signs;
    reg [10:0][7:0] term_values;
    reg [15:0] parse_counter;
    reg [15:0] solve_counter;
    reg [15:0] output_counter;
    reg [7:0] current_sum;
    reg [7:0] remaining_diff;
    reg [3:0] pos_count;
    reg [3:0] neg_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 0;
            is_possible <= 0;
            num_terms <= 0;
            parse_counter <= 0;
            solve_counter <= 0;
            output_counter <= 0;
            term_count <= 0;
            target_n <= 0;
            current_sum <= 0;
            remaining_diff <= 0;
            pos_count <= 0;
            neg_count <= 0;
            for (int i = 0; i < MAX_TERMS; i = i + 1) begin
                term_signs[i] <= 0;
                term_values[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE;
                        parse_counter <= 0;
                        term_count <= 0;
                        target_n <= n_in;
                        pos_count <= 0;
                        neg_count <= 0;
                        for (int i = 0; i < MAX_TERMS; i = i + 1) begin
                            term_signs[i] <= 0;
                            term_values[i] <= 1;
                        end
                    end
                end
                PARSE: begin
                    if (parse_counter < 200) begin
                        if (char_in[parse_counter*8 +: 8] == "?") begin
                            if (term_count < MAX_TERMS) begin
                                term_count <= term_count + 1;
                                if (parse_counter > 0 && char_in[(parse_counter-1)*8 +: 8] == "+") begin
                                    term_signs[term_count] <= 1;
                                    pos_count <= pos_count + 1;
                                end else if (parse_counter > 0 && char_in[(parse_counter-1)*8 +: 8] == "-") begin
                                    term_signs[term_count] <= 0;
                                    neg_count <= neg_count + 1;
                                end
                            end
                        end
                        parse_counter <= parse_counter + 1;
                    end else begin
                        state <= SOLVE;
                        solve_counter <= 0;
                        current_sum <= pos_count - neg_count;
                        remaining_diff <= (current_sum > target_n) ? (current_sum - target_n) : (target_n - current_sum);
                    end
                end
                SOLVE: begin
                    if (solve_counter < 30) begin
                        solve_counter <= solve_counter + 1;
                    end else begin
                        if (current_sum == target_n) begin
                            is_possible <= 1;
                        end else begin
                            is_possible <= 0;
                        end
                        state <= OUTPUT;
                        output_counter <= 0;
                    end
                end
                OUTPUT: begin
                    if (output_counter < 1) begin
                        output_counter <= output_counter + 1;
                    end else begin
                        result_valid <= 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    always @(posedge clk) begin
        if (state == SOLVE && solve_counter < 30) begin
            if (current_sum < target_n) begin
                for (int i = 0; i < term_count; i = i + 1) begin
                    if (term_signs[i] && term_values[i] < target_n) begin
                        term_values[i] <= term_values[i] + 1;
                        current_sum <= current_sum + 1;
                        if (current_sum == target_n) break;
                    end
                end
            end else if (current_sum > target_n) begin
                for (int i = 0; i < term_count; i = i + 1) begin
                    if (!term_signs[i] && term_values[i] < target_n) begin
                        term_values[i] <= term_values[i] + 1;
                        current_sum <= current_sum - 1;
                        if (current_sum == target_n) break;
                    end
                end
            end
        end
    end

    assign sol_vals = term_values;
    assign sol_signs = term_signs;
    assign num_terms = term_count;

endmodule