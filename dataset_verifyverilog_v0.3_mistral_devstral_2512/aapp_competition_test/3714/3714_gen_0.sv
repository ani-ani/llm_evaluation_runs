module arpa_land (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [2:0] crush_0,
    input wire [2:0] crush_1,
    input wire [2:0] crush_2,
    input wire [2:0] crush_3,
    input wire [2:0] crush_4,
    input wire [2:0] crush_5,
    input wire [2:0] crush_6,
    input wire [2:0] crush_7,
    output reg [9:0] result,
    output reg done
);

    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_INIT = 4'd1;
    localparam [3:0] S_CHECK = 4'd2;
    localparam [3:0] S_TRAVERSE = 4'd3;
    localparam [3:0] S_ADJUST = 4'd4;
    localparam [3:0] S_NEXT = 4'd5;
    localparam [3:0] S_COMPUTE = 4'd6;
    localparam [3:0] S_DONE = 4'd7;
    localparam [3:0] S_ERROR = 4'd8;

    reg [3:0] state, next_state;
    reg [2:0] n_reg;
    reg [2:0] crush_reg [0:7];
    reg visited [0:7];
    reg [2:0] i;
    reg [2:0] current;
    reg [2:0] start_node;
    reg [3:0] count;
    reg [1:0] max2;
    reg max3, max5, max7;
    reg error;

    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: if (start) next_state = S_INIT;
            S_INIT: next_state = S_CHECK;
            S_CHECK: begin
                if (i < n_reg) begin
                    if (!visited[i]) next_state = S_TRAVERSE;
                    else next_state = S_NEXT;
                end else begin
                    if (error) next_state = S_ERROR;
                    else next_state = S_COMPUTE;
                end
            end
            S_TRAVERSE: begin
                if (visited[current]) begin
                    if (current == start_node) next_state = S_ADJUST;
                    else next_state = S_ERROR;
                end else begin
                    next_state = S_TRAVERSE;
                end
            end
            S_ADJUST: next_state = S_NEXT;
            S_NEXT: next_state = S_CHECK;
            S_COMPUTE: next_state = S_DONE;
            S_DONE: next_state = S_DONE;
            S_ERROR: next_state = S_DONE;
            default: next_state = S_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= 10'd0;
            n_reg <= 3'd0;
            for (integer idx = 0; idx < 8; idx = idx + 1) begin
                crush_reg[idx] <= 3'd0;
                visited[idx] <= 1'b0;
            end
            i <= 3'd0;
            current <= 3'd0;
            start_node <= 3'd0;
            count <= 4'd0;
            max2 <= 2'd0;
            max3 <= 1'b0;
            max5 <= 1'b0;
            max7 <= 1'b0;
            error <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                S_IDLE: if (start) begin
                    n_reg <= (n > 3'd0 && n <= 3'd8) ? n : 3'd8;
                    crush_reg[0] <= crush_0;
                    crush_reg[1] <= crush_1;
                    crush_reg[2] <= crush_2;
                    crush_reg[3] <= crush_3;
                    crush_reg[4] <= crush_4;
                    crush_reg[5] <= crush_5;
                    crush_reg[6] <= crush_6;
                    crush_reg[7] <= crush_7;
                    done <= 1'b0;
                    result <= 10'd0;
                    error <= 1'b0;
                end
                S_INIT: begin
                    for (integer idx = 0; idx < 8; idx = idx + 1) begin
                        visited[idx] <= (idx < n_reg) ? 1'b0 : 1'b1;
                    end
                    i <= 3'd0;
                    max2 <= 2'd0;
                    max3 <= 1'b0;
                    max5 <= 1'b0;
                    max7 <= 1'b0;
                end
                S_CHECK: begin
                    if (i < n_reg && visited[i]) begin
                        i <= i + 3'd1;
                    end
                end
                S_TRAVERSE: begin
                    if (!visited[current]) begin
                        visited[current] <= 1'b1;
                        current <= crush_reg[current];
                        count <= count + 4'd1;
                    end
                end
                S_ADJUST: begin
                    if (count % 2 == 0) begin
                        count <= count >> 1;
                    end
                    case (count)
                        1: begin end
                        2: if (max2 < 2'd1) max2 <= 2'd1;
                        3: max3 <= 1'b1;
                        4: if (max2 < 2'd2) max2 <= 2'd2;
                        5: max5 <= 1'b1;
                        7: max7 <= 1'b1;
                        default: error <= 1'b1;
                    endcase
                    count <= 4'd0;
                    i <= i + 3'd1;
                end
                S_NEXT: begin
                    if (i < n_reg && !visited[i]) begin
                        current <= i;
                        start_node <= i;
                        count <= 4'd0;
                    end
                end
                S_COMPUTE: begin
                    result <= (1 << max2) * (max3 ? 3 : 1) * (max5 ? 5 : 1) * (max7 ? 7 : 1);
                end
                S_DONE: begin
                    done <= 1'b1;
                    if (state == S_ERROR) begin
                        result <= 10'h3FF;
                    end
                end
                S_ERROR: begin
                    error <= 1'b1;
                end
            endcase
        end
    end

endmodule