module lure_of_the_labyrinth (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input valid_in,
    output reg [31:0] solution_count,
    output reg many,
    output reg done
);

    reg [2:0] state;
    reg [19:0] input_data;
    reg [4:0] input_count;
    reg [7:0] p_count, q_count;
    reg [31:0] total_valid;
    reg many_reg, solution_count_reg, done_reg;

    wire [7:0] current_p, current_q;
    assign current_p = p_count;
    assign current_q = q_count;

    wire all_unknown;
    generate
        all_unknown = 1;
        for (int i=0; i<20; i++) begin
            all_unknown = all_unknown & (input_data[i] == 0);
        end
    endgenerate

    wire valid_pair;
    generate
        valid_pair = 1;
        for (int i=0; i<20; i++) begin
            if (input_data[i] != 0) begin
                if ((input_data[i] * current_q) % current_p != 0) begin
                    valid_pair = 0;
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= 3'b000;
            input_count <= 5'b00000;
            input_data <= 20'b0;
            p_count <= 8'b00000000;
            q_count <= 8'b00000000;
            total_valid <= 32'b0;
            many_reg <= 1'b0;
            solution_count_reg <= 32'b0;
            done_reg <= 1'b0;
        end else begin
            case (state)
                3'b000:
                    if (start) state <= 3'b001;
                3'b001:
                    if (valid_in) begin
                        input_data[input_count] <= data_in;
                        input_count <= input_count + 1;
                    end
                    if (input_count == 20) begin
                        state <= 3'b010;
                        input_count <= 5'b00000;
                        p_count <= 8'b00000001;
                        q_count <= 8'b00000001;
                    end
                3'b010:
                    if (all_unknown) begin
                        many_reg <= 1'b1;
                        solution_count_reg <= 32'b0;
                        done_reg <= 1'b1;
                        state <= 3'b011;
                    end else begin
                        if (p_count > 200) begin
                            solution_count_reg <= total_valid;
                            many_reg <= 1'b0;
                            done_reg <= 1'b1;
                            state <= 3'b011;
                        end else begin
                            if (q_count < 200) begin
                                q_count <= q_count + 1;
                            end else begin
                                q_count <= 8'b00000001;
                                if (p_count == 200) begin
                                    p_count <= 201;
                                end else begin
                                    p_count <= p_count + 1;
                                end
                            end
                            if (valid_pair) begin
                                total_valid <= total_valid + 1;
                            end
                        end
                    end
                3'b011:
            endcase
        end
    end

    assign solution_count = solution_count_reg;
    assign many = many_reg;
    assign done = done_reg;

endmodule