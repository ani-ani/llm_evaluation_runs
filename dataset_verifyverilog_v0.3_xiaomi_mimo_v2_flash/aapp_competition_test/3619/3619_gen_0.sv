module EmployeeSelector (
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [31:0] lambda,
    input [15:0] s_1, s_2, s_3, s_4,
    input [15:0] p_1, p_2, p_3, p_4,
    input [15:0] r_1, r_2, r_3, r_4,
    output reg [63:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRECOMPUTE = 3'd1;
    localparam [2:0] ITERATE = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] k_reg;
    reg [31:0] lambda_reg;
    reg [15:0] s_reg [0:3];
    reg [15:0] p_reg [0:3];
    reg [15:0] r_reg [0:3];
    reg [63:0] term [0:3];
    reg [63:0] best_total;
    reg [3:0] mask_counter;
    reg [3:0] i;
    reg valid_reg;

    // Combinational logic for validity check
    always @(*) begin
        valid_reg = 1'b1;
        for (i = 4'd0; i < 4'd4; i = i + 1) begin
            if (mask_counter[i] && (r_reg[i] != 16'd0)) begin
                integer ref_idx;
                ref_idx = r_reg[i] - 16'd1;
                if (ref_idx < 0 || ref_idx >= 4) begin
                    valid_reg = 1'b0;
                end else if (!mask_counter[ref_idx]) begin
                    valid_reg = 1'b0;
                end
            end
        end
    end

    // Combinational logic for total calculation
    wire [63:0] current_total;
    assign current_total = 
        (mask_counter[0] ? term[0] : 64'd0) +
        (mask_counter[1] ? term[1] : 64'd0) +
        (mask_counter[2] ? term[2] : 64'd0) +
        (mask_counter[3] ? term[3] : 64'd0);

    // Combinational logic for popcount
    wire [2:0] popcount;
    assign popcount = mask_counter[0] + mask_counter[1] + mask_counter[2] + mask_counter[3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
            mask_counter <= 4'd0;
            best_total <= 64'd0;
            k_reg <= 3'd0;
            lambda_reg <= 32'd0;
            for (i = 4'd0; i < 4'd4; i = i + 1) begin
                s_reg[i] <= 16'd0;
                p_reg[i] <= 16'd0;
                r_reg[i] <= 16'd0;
                term[i] <= 64'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        k_reg <= k;
                        lambda_reg <= lambda;
                        s_reg[0] <= s_1;
                        s_reg[1] <= s_2;
                        s_reg[2] <= s_3;
                        s_reg[3] <= s_4;
                        p_reg[0] <= p_1;
                        p_reg[1] <= p_2;
                        p_reg[2] <= p_3;
                        p_reg[3] <= p_4;
                        r_reg[0] <= r_1;
                        r_reg[1] <= r_2;
                        r_reg[2] <= r_3;
                        r_reg[3] <= r_4;
                        state <= PRECOMPUTE;
                        mask_counter <= 4'd0;
                        best_total <= 64'h8000000000000000;
                    end
                end

                PRECOMPUTE: begin
                    // Q16.16 multiplication: lambda * s
                    term[0] <= ({{48{p_reg[0][15]}}, p_reg[0]} << 16) - (lambda_reg * s_reg[0]);
                    term[1] <= ({{48{p_reg[1][15]}}, p_reg[1]} << 16) - (lambda_reg * s_reg[1]);
                    term[2] <= ({{48{p_reg[2][15]}}, p_reg[2]} << 16) - (lambda_reg * s_reg[2]);
                    term[3] <= ({{48{p_reg[3][15]}}, p_reg[3]} << 16) - (lambda_reg * s_reg[3]);
                    state <= ITERATE;
                end

                ITERATE: begin
                    if (popcount == k_reg && valid_reg) begin
                        if (current_total > best_total) begin
                            best_total <= current_total;
                        end
                    end
                    if (mask_counter == 4'hF) begin
                        state <= DONE;
                    end else begin
                        mask_counter <= mask_counter + 4'd1;
                    end
                end

                DONE: begin
                    result <= best_total;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule