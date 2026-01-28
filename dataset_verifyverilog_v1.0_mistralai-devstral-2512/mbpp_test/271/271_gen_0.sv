module even_fifth_power_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    localparam [7:0] DATA_WIDTH = 32;
    localparam [7:0] ITER_WIDTH = 8;

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] COMPUTE_J = 3'd2;
    localparam [2:0] MUL1      = 3'd3;
    localparam [2:0] MUL2      = 3'd4;
    localparam [2:0] MUL3      = 3'd5;
    localparam [2:0] MUL4      = 3'd6;
    localparam [2:0] ACCUM     = 3'd7;
    localparam [2:0] FINISH    = 3'd8;

    // Internal registers
    reg [2:0] state;
    reg [7:0] i;
    reg [31:0] sum;
    reg [31:0] j;
    reg [31:0] j_sq;
    reg [31:0] j_cu;
    reg [31:0] j_qu;
    reg [31:0] j_quint;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2560;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 8'd0;
            sum <= 32'd0;
            j <= 32'd0;
            j_sq <= 32'd0;
            j_cu <= 32'd0;
            j_qu <= 32'd0;
            j_quint <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    i <= 8'd1;
                    sum <= 32'd0;
                    state <= COMPUTE_J;
                end

                COMPUTE_J: begin
                    j <= 2 * i;
                    state <= MUL1;
                end

                MUL1: begin
                    j_sq <= j * j;
                    state <= MUL2;
                end

                MUL2: begin
                    j_cu <= j_sq * j;
                    state <= MUL3;
                end

                MUL3: begin
                    j_qu <= j_cu * j;
                    state <= MUL4;
                end

                MUL4: begin
                    j_quint <= j_qu * j;
                    state <= ACCUM;
                end

                ACCUM: begin
                    sum <= sum + j_quint;
                    cycle_count <= cycle_count + 8'd1;
                    if (i == n || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        i <= i + 8'd1;
                        state <= COMPUTE_J;
                    end
                end

                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule