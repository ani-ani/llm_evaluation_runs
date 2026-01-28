module char_compare(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPARE = 2'd2;

    // Internal signals
    reg [1:0] state, next_state;
    reg [7:0] first_char;
    reg [2:0] compare_index;
    reg [7:0] current_char;
    reg all_match;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            first_char <= 8'd0;
            compare_index <= 3'd0;
            all_match <= 1'b1;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                next_state = COMPARE;
            end
            COMPARE: begin
                if (compare_index == 3'd7) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            first_char <= 8'd0;
            compare_index <= 3'd0;
            all_match <= 1'b1;
            current_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    result <= 1'b0;
                    done <= 1'b0;
                end
                LOAD: begin
                    first_char <= char[0];
                    compare_index <= 3'd1;
                    all_match <= 1'b1;
                end
                COMPARE: begin
                    current_char <= char[compare_index];
                    if (current_char != first_char) begin
                        all_match <= 1'b0;
                    end
                    if (compare_index == 3'd7) begin
                        result <= all_match;
                        done <= 1'b1;
                    end else begin
                        compare_index <= compare_index + 3'd1;
                        done <= 1'b0;
                    end
                end
                default: begin
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule