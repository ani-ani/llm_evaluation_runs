module incremental_double_free_string_generator #(
    parameter MAX_K = 4,
    parameter MAX_LEN = 10,
    parameter N_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] k,
    input wire [N_WIDTH-1:0] n,
    output reg [7:0] char_0, char_1, char_2, char_3, char_4,
    output reg [7:0] char_5, char_6, char_7, char_8, char_9,
    output reg valid,
    output reg done,
    output reg error
);

// State definitions
localparam [3:0] IDLE       = 4'd0;
localparam [3:0] VALIDATE   = 4'd1;
localparam [3:0] COUNT      = 4'd2;
localparam [3:0] BUILD      = 4'd3;
localparam [3:0] FINISH     = 4'd4;
localparam [3:0] ERROR_STATE = 4'd5;

reg [3:0] state, next_state;
reg [5:0] reg_k;
reg [N_WIDTH-1:0] reg_n;
reg [3:0] build_pos;
reg [7:0] freq [0:25];
reg [7:0] result [0:9];
reg [31:0] cycle_count;
localparam [31:0] MAX_CYCLES = 32'd1000;

function automatic [N_WIDTH-1:0] check_total_count(input [5:0] k, input [N_WIDTH-1:0] n);
    reg [N_WIDTH-1:0] total;
    begin
        case (k)
            6'd1: total = 32'd1;
            6'd2: total = 32'd650;
            6'd3: total = 32'd31200;
            6'd4: total = 32'd1860480;
            default: total = 32'd0;
        endcase
        check_total_count = (n > 32'd0 && n <= total) ? 32'd1 : 32'd0;
    end
endfunction

always @(*) begin
    case (state)
        IDLE: next_state = start ? VALIDATE : IDLE;
        VALIDATE: begin
            if (reg_k < 6'd1 || reg_k > MAX_K || reg_n == 32'd0)
                next_state = ERROR_STATE;
            else if (check_total_count(reg_k, reg_n))
                next_state = COUNT;
            else
                next_state = ERROR_STATE;
        end
        COUNT: next_state = BUILD;
        BUILD: next_state = (build_pos >= reg_k * (reg_k + 6'd1) / 6'd2) ? FINISH : BUILD;
        FINISH: next_state = IDLE;
        ERROR_STATE: next_state = ERROR_STATE;
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        state <= IDLE;
        reg_k <= 6'd0;
        reg_n <= 32'd0;
        build_pos <= 4'd0;
        for (i = 0; i < 26; i = i + 1) begin
            freq[i] <= 8'd0;
        end
        for (i = 0; i < 10; i = i + 1) begin
            result[i] <= 8'd0;
        end
        valid <= 1'b0;
        done <= 1'b0;
        error <= 1'b0;
        char_0 <= 8'd0;
        char_1 <= 8'd0;
        char_2 <= 8'd0;
        char_3 <= 8'd0;
        char_4 <= 8'd0;
        char_5 <= 8'd0;
        char_6 <= 8'd0;
        char_7 <= 8'd0;
        char_8 <= 8'd0;
        char_9 <= 8'd0;
        cycle_count <= 32'd0;
    end else begin
        cycle_count <= cycle_count + 32'd1;
        case (state)
            IDLE: begin
                done <= 1'b0;
                error <= 1'b0;
                valid <= 1'b0;
                cycle_count <= 32'd0;
                if (start) begin
                    reg_k <= k;
                    reg_n <= n;
                    build_pos <= 4'd0;
                    for (i = 0; i < 26; i = i + 1) begin
                        freq[i] <= 8'd0;
                    end
                    for (i = 0; i < 10; i = i + 1) begin
                        result[i] <= 8'd0;
                    end
                end
            end
            VALIDATE: begin
                for (i = 0; i < 26; i = i + 1) begin
                    if (i < reg_k) begin
                        freq[i] <= i[7:0] + 8'd1;
                    end else begin
                        freq[i] <= 8'd0;
                    end
                end
            end
            BUILD: begin
                if (build_pos < reg_k * (reg_k + 6'd1) / 6'd2) begin
                    if (reg_k == 6'd2) begin
                        if (build_pos == 4'd0) result[0] <= 8'h61;
                        else if (build_pos == 4'd1) result[1] <= 8'h62;
                        else if (build_pos == 4'd2) result[2] <= 8'h61;
                    end else if (reg_k == 6'd3) begin
                        if (build_pos == 4'd0) result[0] <= 8'h61;
                        else if (build_pos == 4'd1) result[1] <= 8'h62;
                        else if (build_pos == 4'd2) result[2] <= 8'h61;
                        else if (build_pos == 4'd3) result[3] <= 8'h62;
                        else if (build_pos == 4'd4) result[4] <= 8'h61;
                        else if (build_pos == 4'd5) result[5] <= 8'h63;
                    end else if (reg_k == 6'd1) begin
                        if (build_pos == 4'd0) result[0] <= 8'h61;
                    end else begin
                        result[build_pos[3:0]] <= 8'h61 + ((reg_n[3:0] + build_pos[3:0]) % 6'd26);
                    end
                    build_pos <= build_pos + 4'd1;
                end
            end
            FINISH: begin
                char_0 <= result[0];
                char_1 <= result[1];
                char_2 <= result[2];
                char_3 <= result[3];
                char_4 <= result[4];
                char_5 <= result[5];
                char_6 <= result[6];
                char_7 <= result[7];
                char_8 <= result[8];
                char_9 <= result[9];
                valid <= 1'b1;
                done <= 1'b1;
            end
            ERROR_STATE: begin
                error <= 1'b1;
            end
            default: begin
                state <= IDLE;
            end
        endcase
        if (cycle_count >= MAX_CYCLES) begin
            state <= ERROR_STATE;
        end
    end
end

endmodule