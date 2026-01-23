module settle_bills (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] receipt_a,
    input wire [2:0] receipt_b,
    input wire [9:0] receipt_p,
    input wire receipt_valid,
    input wire last,
    output reg [3:0] result,
    output reg done
);

// Parameters
parameter MAX_PEOPLE = 8;
localparam BALANCE_WIDTH = 32;
localparam RESULT_WIDTH = 4;
localparam STATE_WIDTH = 5;

// State definitions
localparam [STATE_WIDTH-1:0] S_IDLE              = 5'd0;
localparam [STATE_WIDTH-1:0] S_PROCESS_RECEIPTS  = 5'd1;
localparam [STATE_WIDTH-1:0] S_COUNT_NONZERO     = 5'd2;
localparam [STATE_WIDTH-1:0] S_COMPONENT_START   = 5'd3;
localparam [STATE_WIDTH-1:0] S_COMPONENT_LOOP    = 5'd4;
localparam [STATE_WIDTH-1:0] S_COMPONENT_PROPAGATE_INIT = 5'd5;
localparam [STATE_WIDTH-1:0] S_COMPONENT_PROPAGATE_LOOP = 5'd6;
localparam [STATE_WIDTH-1:0] S_COMPONENT_PROPAGATE_J    = 5'd7;
localparam [STATE_WIDTH-1:0] S_COMPONENT_PROPAGATE_K    = 5'd8;
localparam [STATE_WIDTH-1:0] S_COMPUTE_RESULT    = 5'd9;
localparam [STATE_WIDTH-1:0] S_DONE              = 5'd10;

// Registers
reg [STATE_WIDTH-1:0] state, next_state;
reg [BALANCE_WIDTH-1:0] balance [0:MAX_PEOPLE-1];
reg [MAX_PEOPLE-1:0] adjacency [0:MAX_PEOPLE-1];
reg [MAX_PEOPLE-1:0] visited;
reg [RESULT_WIDTH-1:0] non_zero_count;
reg [RESULT_WIDTH-1:0] component_count;
reg [2:0] i, j, k;
reg changed;
reg [RESULT_WIDTH-1:0] result_reg;
reg done_reg;
reg first_nonzero_found;

// Integer for loops
integer idx;

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done_reg <= 1'b0;
        result_reg <= 4'd0;
        non_zero_count <= 4'd0;
        component_count <= 4'd0;
        visited <= 8'd0;
        changed <= 1'b0;
        i <= 3'd0;
        j <= 3'd0;
        k <= 3'd0;
        first_nonzero_found <= 1'b0;
        for (idx = 0; idx < MAX_PEOPLE; idx = idx + 1) begin
            balance[idx] <= 32'd0;
            adjacency[idx] <= 8'd0;
        end
    end else begin
        state <= next_state;
        done_reg <= 1'b0;
        result_reg <= result_reg;

        case (state)
            S_IDLE: begin
                if (start) begin
                    for (idx = 0; idx < MAX_PEOPLE; idx = idx + 1) begin
                        balance[idx] <= 32'd0;
                        adjacency[idx] <= 8'd0;
                    end
                end
            end

            S_PROCESS_RECEIPTS: begin
                if (receipt_valid) begin
                    if (receipt_a < MAX_PEOPLE && receipt_b < MAX_PEOPLE) begin
                        if (balance[receipt_a] >= {22'd0, receipt_p}) begin
                            balance[receipt_a] <= balance[receipt_a] - {22'd0, receipt_p};
                        end else begin
                            balance[receipt_a] <= 32'd0;
                        end
                        balance[receipt_b] <= balance[receipt_b] + {22'd0, receipt_p};
                        adjacency[receipt_a][receipt_b] <= 1'b1;
                        adjacency[receipt_b][receipt_a] <= 1'b1;
                    end
                end
            end

            S_COUNT_NONZERO: begin
                if (i < MAX_PEOPLE) begin
                    if (balance[i] != 32'd0) begin
                        non_zero_count <= non_zero_count + 4'd1;
                    end
                    i <= i + 3'd1;
                end
            end

            S_COMPONENT_START: begin
                visited <= 8'd0;
                component_count <= 4'd0;
                i <= 3'd0;
                first_nonzero_found <= 1'b0;
            end

            S_COMPONENT_LOOP: begin
                if (i < MAX_PEOPLE) begin
                    if (balance[i] != 32'd0 && !visited[i]) begin
                        visited[i] <= 1'b1;
                        component_count <= component_count + 4'd1;
                        changed <= 1'b1;
                        first_nonzero_found <= 1'b1;
                    end else begin
                        i <= i + 3'd1;
                    end
                end
            end

            S_COMPONENT_PROPAGATE_LOOP: begin
                if (!changed && first_nonzero_found) begin
                    i <= i + 3'd1;
                    first_nonzero_found <= 1'b0;
                end else begin
                    j <= 3'd0;
                end
            end

            S_COMPONENT_PROPAGATE_J: begin
                if (j < MAX_PEOPLE) begin
                    if (visited[j]) begin
                        k <= 3'd0;
                    end else begin
                        j <= j + 3'd1;
                    end
                end else begin
                    // Finished scanning j for this iteration
                    changed <= 1'b0;
                end
            end

            S_COMPONENT_PROPAGATE_K: begin
                if (k < MAX_PEOPLE) begin
                    if (adjacency[j][k] && balance[k] != 32'd0 && !visited[k]) begin
                        visited[k] <= 1'b1;
                        changed <= 1'b1;
                    end
                    k <= k + 3'd1;
                end else begin
                    j <= j + 3'd1;
                end
            end

            S_COMPUTE_RESULT: begin
                if (non_zero_count >= component_count) begin
                    result_reg <= non_zero_count - component_count;
                end else begin
                    result_reg <= 4'd0;
                end
                done_reg <= 1'b1;
            end

            S_DONE: begin
                done_reg <= 1'b1;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    case (state)
        S_IDLE: begin
            if (start) next_state = S_PROCESS_RECEIPTS;
            else next_state = S_IDLE;
        end

        S_PROCESS_RECEIPTS: begin
            if (receipt_valid && last) next_state = S_COUNT_NONZERO;
            else next_state = S_PROCESS_RECEIPTS;
        end

        S_COUNT_NONZERO: begin
            if (i < MAX_PEOPLE) next_state = S_COUNT_NONZERO;
            else next_state = S_COMPONENT_START;
        end

        S_COMPONENT_START: begin
            next_state = S_COMPONENT_LOOP;
        end

        S_COMPONENT_LOOP: begin
            if (i < MAX_PEOPLE) begin
                if (balance[i] != 32'd0 && !visited[i]) begin
                    next_state = S_COMPONENT_PROPAGATE_LOOP;
                end else begin
                    next_state = S_COMPONENT_LOOP;
                end
            end else begin
                next_state = S_COMPUTE_RESULT;
            end
        end

        S_COMPONENT_PROPAGATE_LOOP: begin
            if (changed) next_state = S_COMPONENT_PROPAGATE_J;
            else if (first_nonzero_found) next_state = S_COMPONENT_LOOP;
            else next_state = S_COMPONENT_LOOP;
        end

        S_COMPONENT_PROPAGATE_J: begin
            if (j < MAX_PEOPLE) begin
                if (visited[j]) next_state = S_COMPONENT_PROPAGATE_K;
                else next_state = S_COMPONENT_PROPAGATE_J;
            end else begin
                next_state = S_COMPONENT_PROPAGATE_LOOP;
            end
        end

        S_COMPONENT_PROPAGATE_K: begin
            if (k < MAX_PEOPLE) next_state = S_COMPONENT_PROPAGATE_K;
            else next_state = S_COMPONENT_PROPAGATE_J;
        end

        S_COMPUTE_RESULT: begin
            next_state = S_DONE;
        end

        S_DONE: begin
            next_state = S_DONE;
        end

        default: next_state = S_IDLE;
    endcase
end

// Output assignments
always @(*) begin
    result = result_reg;
    done = done_reg;
end

endmodule