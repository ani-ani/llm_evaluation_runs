module candidate_simulation #(
    parameter N = 8,
    parameter VALUE_WIDTH = 8,
    parameter MAX_MINUTES = 16,
    parameter MINUTE_WIDTH = 5,
    parameter LEN_WIDTH = 4
)(
    input clk,
    input rst_n,
    input start,
    input [LEN_WIDTH-1:0] len,
    input [VALUE_WIDTH-1:0] val0, val1, val2, val3, val4, val5, val6, val7,
    output reg done,
    output reg [MINUTE_WIDTH-1:0] M,
    output reg [VALUE_WIDTH-1:0] final0, final1, final2, final3, final4, final5, final6, final7,
    output reg [LEN_WIDTH-1:0] final_len
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] REMOVE = 3'd2;
    localparam [2:0] DONE = 3'd3;

    reg [2:0] state, next_state;
    reg [VALUE_WIDTH-1:0] current_values [0:N-1];
    reg [LEN_WIDTH-1:0] current_len_reg;
    reg [MINUTE_WIDTH-1:0] minute_count;
    wire [N-1:0] leaving_mask;
    reg [VALUE_WIDTH-1:0] new_values [0:N-1];
    reg [LEN_WIDTH-1:0] new_len;
    integer i;
    reg cycle_flag;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            if (i < current_len_reg) begin
                leaving_mask[i] = 1'b0;
                if (i > 0) begin
                    if (current_values[i-1] > current_values[i])
                        leaving_mask[i] = 1'b1;
                end
                if (i < current_len_reg - 1) begin
                    if (current_values[i+1] > current_values[i])
                        leaving_mask[i] = 1'b1;
                end
            end else begin
                leaving_mask[i] = 1'b0;
            end
        end
    end

    always @(*) begin
        new_len = 0;
        for (i = 0; i < N; i = i + 1) begin
            if (i < current_len_reg) begin
                if (leaving_mask[i] == 1'b0) begin
                    new_values[new_len] = current_values[i];
                    new_len = new_len + 1;
                end
            end
        end
    end

    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? COMPUTE : IDLE;
            COMPUTE: begin
                if (leaving_mask == 0) next_state = DONE;
                else next_state = REMOVE;
            end
            REMOVE: next_state = COMPUTE;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            M <= 0;
            current_len_reg <= 0;
            minute_count <= 0;
            final0 <= 0; final1 <= 0; final2 <= 0; final3 <= 0;
            final4 <= 0; final5 <= 0; final6 <= 0; final7 <= 0;
            final_len <= 0;
            cycle_flag <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                current_values[i] <= 0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        current_values[0] <= val0;
                        current_values[1] <= val1;
                        current_values[2] <= val2;
                        current_values[3] <= val3;
                        current_values[4] <= val4;
                        current_values[5] <= val5;
                        current_values[6] <= val6;
                        current_values[7] <= val7;
                        current_len_reg <= len;
                        minute_count <= 0;
                        done <= 1'b0;
                        cycle_flag <= 1'b0;
                    end
                end
                COMPUTE: begin
                    if (leaving_mask == 0 && !cycle_flag) begin
                        M <= minute_count;
                        final0 <= current_values[0];
                        final1 <= current_values[1];
                        final2 <= current_values[2];
                        final3 <= current_values[3];
                        final4 <= current_values[4];
                        final5 <= current_values[5];
                        final6 <= current_values[6];
                        final7 <= current_values[7];
                        final_len <= current_len_reg;
                        done <= 1'b1;
                        cycle_flag <= 1'b1;
                    end
                end
                REMOVE: begin
                    minute_count <= minute_count + 1;
                    for (i = 0; i < N; i = i + 1) begin
                        current_values[i] <= new_values[i];
                    end
                    current_len_reg <= new_len;
                end
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule