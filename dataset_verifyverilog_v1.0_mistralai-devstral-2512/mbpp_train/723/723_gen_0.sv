module ArrayMatchCounter(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr1_i [0:7],
    input signed [7:0] arr2_i [0:7],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal signals
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [15:0] match_count;

    // Combinatorial equality comparison for each index
    wire [0:7] match_flags;
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : match_gen
            assign match_flags[i] = (arr1_i[i] == arr2_i[i]);
        end
    endgenerate

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPARE;
                else
                    next_state = IDLE;
            end
            COMPARE: begin
                if (index == len - 1)
                    next_state = FINISH;
                else
                    next_state = COMPARE;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register and index management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            match_count <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        index <= 4'd0;
                        match_count <= 16'd0;
                    end
                end
                COMPARE: begin
                    if (match_flags[index])
                        match_count <= match_count + 16'd1;
                    if (index < len - 1)
                        index <= index + 4'd1;
                end
                FINISH: begin
                    result <= match_count;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule