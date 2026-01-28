module InversionCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input [7:0] arr [0:15],
    input [4:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] COMPARE  = 3'd2;
    localparam [2:0] NEXT_J   = 3'd3;
    localparam [2:0] NEXT_I   = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] i_reg, j_reg;
    reg [15:0] count_reg;
    reg [7:0] arr_i, arr_j;
    reg [7:0] arr_storage [0:15];
    reg [4:0] len_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                next_state = COMPARE;
            end
            COMPARE: begin
                if (arr_i > arr_j)
                    next_state = NEXT_J;
                else
                    next_state = NEXT_J;
            end
            NEXT_J: begin
                if (j_reg + 1 < len_reg)
                    next_state = COMPARE;
                else
                    next_state = NEXT_I;
            end
            NEXT_I: begin
                if (i_reg + 1 < len_reg - 1)
                    next_state = COMPARE;
                else
                    next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            count_reg <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            len_reg <= 5'd0;
            // Initialize array storage
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                arr_storage[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                LOAD: begin
                    len_reg <= len;
                    // Load array into storage
                    integer k;
                    for (k = 0; k < 16; k = k + 1) begin
                        arr_storage[k] <= arr[k];
                    end
                    i_reg <= 4'd0;
                    j_reg <= 4'd1;
                    count_reg <= 16'd0;
                end
                COMPARE: begin
                    arr_i <= arr_storage[i_reg];
                    arr_j <= arr_storage[j_reg];
                end
                NEXT_J: begin
                    if (arr_i > arr_j)
                        count_reg <= count_reg + 16'd1;
                    j_reg <= j_reg + 4'd1;
                end
                NEXT_I: begin
                    i_reg <= i_reg + 4'd1;
                    j_reg <= i_reg + 4'd1;
                end
                DONE_STATE: begin
                    result <= count_reg;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety: Prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end
    end

endmodule