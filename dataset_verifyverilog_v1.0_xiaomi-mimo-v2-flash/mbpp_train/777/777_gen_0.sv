module sum_non_repeated (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COUNT     = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] ADD       = 3'd4;
    localparam [2:0] NEXT      = 3'd5;
    localparam [2:0] FINISH    = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] temp_sum;
    reg [3:0] current_idx;
    reg [3:0] check_idx;
    reg [7:0] current_val;
    reg [3:0] occurrence_count;
    reg [3:0] cycle_counter;

    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? LOAD : IDLE;
            LOAD:       next_state = (current_idx >= len) ? FINISH : COUNT;
            COUNT:      next_state = CHECK;
            CHECK:      begin
                if (check_idx >= len) begin
                    next_state = ADD;
                end else begin
                    next_state = CHECK;
                end
            end
            ADD:        next_state = NEXT;
            NEXT:       next_state = LOAD;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            temp_sum <= 16'd0;
            current_idx <= 4'd0;
            check_idx <= 4'd0;
            current_val <= 8'd0;
            occurrence_count <= 4'd0;
            cycle_counter <= 4'd0;
        end else begin
            state <= next_state;
            cycle_counter <= cycle_counter + 4'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        temp_sum <= 16'd0;
                        current_idx <= 4'd0;
                        cycle_counter <= 4'd0;
                    end
                end

                LOAD: begin
                    if (current_idx < len) begin
                        current_val <= arr[current_idx];
                        occurrence_count <= 4'd0;
                        check_idx <= 4'd0;
                    end
                end

                COUNT: begin
                    check_idx <= 4'd0;
                    occurrence_count <= 4'd0;
                end

                CHECK: begin
                    if (check_idx < len) begin
                        if (arr[check_idx] == current_val) begin
                            occurrence_count <= occurrence_count + 4'd1;
                        end
                        check_idx <= check_idx + 4'd1;
                    end
                end

                ADD: begin
                    if (occurrence_count == 4'd1) begin
                        temp_sum <= temp_sum + {8'd0, current_val};
                    end
                end

                NEXT: begin
                    current_idx <= current_idx + 4'd1;
                end

                FINISH: begin
                    result <= temp_sum;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    temp_sum <= 16'd0;
                    current_idx <= 4'd0;
                    check_idx <= 4'd0;
                    occurrence_count <= 4'd0;
                    cycle_counter <= 4'd0;
                end
            endcase
        end
    end

endmodule