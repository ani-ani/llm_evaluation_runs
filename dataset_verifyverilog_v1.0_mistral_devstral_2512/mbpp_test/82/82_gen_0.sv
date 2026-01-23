module sphere_volume(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] radius,
    output reg [31:0] volume,
    output reg done
);

    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] COMPUTE_R2 = 3'b001;
    localparam [2:0] COMPUTE_R3 = 3'b010;
    localparam [2:0] COMPUTE_R3_PI = 3'b011;
    localparam [2:0] COMPUTE_FINAL = 3'b100;
    localparam [2:0] DONE_STATE = 3'b101;

    localparam [17:0] PI_FIXED = 18'd205887;
    localparam [17:0] FOUR_THIRDS = 18'd87381;

    reg [2:0] state;
    reg [31:0] r2;
    reg [31:0] r3;
    reg [47:0] temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            volume <= 32'd0;
            done <= 1'b0;
            r2 <= 32'd0;
            r3 <= 32'd0;
            temp <= 48'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_R2;
                        r2 <= (radius * radius) >> 8;
                    end
                end

                COMPUTE_R2: begin
                    cycle_count <= cycle_count + 8'd1;
                    r3 <= (r2 * radius) >> 8;
                    state <= COMPUTE_R3;
                end

                COMPUTE_R3: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp <= r3 * PI_FIXED;
                    state <= COMPUTE_R3_PI;
                end

                COMPUTE_R3_PI: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp <= temp >> 8;
                    state <= COMPUTE_FINAL;
                end

                COMPUTE_FINAL: begin
                    cycle_count <= cycle_count + 8'd1;
                    volume <= (temp[31:0] * FOUR_THIRDS) >> 16;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule