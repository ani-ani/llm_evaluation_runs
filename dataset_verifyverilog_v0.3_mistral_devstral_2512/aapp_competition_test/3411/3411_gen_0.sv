module alternating_chain_solver #(
    parameter N = 8,
    parameter DATA_WIDTH = 16,
    parameter RESULT_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [DATA_WIDTH-1:0] s [N-1:0],
    input wire [DATA_WIDTH-1:0] c,
    input wire [DATA_WIDTH-1:0] r,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE_MASK = 3'd2;
    localparam [2:0] COMPUTE_SIGN = 3'd3;
    localparam [2:0] COMPUTE_COST = 3'd4;
    localparam [2:0] UPDATE_MIN = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;
    reg [N-1:0] mask;
    reg start_sign;
    reg [4:0] index;
    reg signed [DATA_WIDTH:0] total_upvotes;
    reg signed [DATA_WIDTH:0] total_downvotes;
    reg [DATA_WIDTH:0] removal_cost;
    reg [DATA_WIDTH:0] voting_cost;
    reg [RESULT_WIDTH-1:0] current_cost;
    reg [RESULT_WIDTH-1:0] min_cost;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= {N{1'b0}};
            start_sign <= 1'b0;
            index <= 5'd0;
            total_upvotes <= {1'b0, {DATA_WIDTH{1'b0}}};
            total_downvotes <= {1'b0, {DATA_WIDTH{1'b0}}};
            removal_cost <= {1'b0, {DATA_WIDTH{1'b0}}};
            voting_cost <= {1'b0, {DATA_WIDTH{1'b0}}};
            current_cost <= 32'd0;
            min_cost <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                    done <= 1'b0;
                end
            end

            INIT: begin
                mask <= {N{1'b0}};
                start_sign <= 1'b0;
                index <= 5'd0;
                min_cost <= 32'd0;
                cycle_count <= 8'd0;
                next_state = COMPUTE_MASK;
            end

            COMPUTE_MASK: begin
                if (index == N) begin
                    next_state = COMPUTE_SIGN;
                end else begin
                    if (mask[index]) begin
                        if (start_sign) begin
                            if (s[index] <= 0) begin
                                total_upvotes <= total_upvotes + (1 - s[index]);
                            end
                        end else begin
                            if (s[index] >= 0) begin
                                total_downvotes <= total_downvotes + (s[index] + 1);
                            end
                        end
                    end
                    index <= index + 1;
                end
            end

            COMPUTE_SIGN: begin
                removal_cost <= r * (N - $clog2(mask));
                if (total_upvotes > total_downvotes) begin
                    voting_cost <= c * total_upvotes;
                end else begin
                    voting_cost <= c * total_downvotes;
                end
                current_cost <= removal_cost + voting_cost;
                next_state = UPDATE_MIN;
            end

            UPDATE_MIN: begin
                if (min_cost == 0 || current_cost < min_cost) begin
                    min_cost <= current_cost;
                end
                if (start_sign) begin
                    if (mask == {N{1'b1}}) begin
                        next_state = FINISH;
                    end else begin
                        mask <= mask + 1;
                        start_sign <= 1'b0;
                    end
                end else begin
                    start_sign <= 1'b1;
                end
                index <= 5'd0;
                total_upvotes <= {1'b0, {DATA_WIDTH{1'b0}}};
                total_downvotes <= {1'b0, {DATA_WIDTH{1'b0}}};
            end

            FINISH: begin
                result <= min_cost;
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule