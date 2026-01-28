module PackmenMinTime(
    input clk,
    input rst_n,
    input start,
    input [3:0] field [0:15],
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] BINARY_SEARCH = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] low;
    reg [7:0] high;
    reg [7:0] mid;
    reg [7:0] cycle_count;
    reg [7:0] max_cycles;
    reg [3:0] packmen_positions [0:15];
    reg [3:0] asterisk_positions [0:15];
    reg [3:0] packmen_count;
    reg [3:0] asterisk_count;
    reg [3:0] current_packman;
    reg [3:0] current_asterisk;
    reg [3:0] eaten_asterisks;
    reg [3:0] temp_packman;
    reg [3:0] temp_asterisk;
    reg [7:0] distance;
    reg feasible;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            low <= 8'd0;
            high <= 8'd255;
            mid <= 8'd0;
            cycle_count <= 8'd0;
            max_cycles <= 8'd512;
            packmen_count <= 4'd0;
            asterisk_count <= 4'd0;
            current_packman <= 4'd0;
            current_asterisk <= 4'd0;
            eaten_asterisks <= 4'd0;
            temp_packman <= 4'd0;
            temp_asterisk <= 4'd0;
            distance <= 8'd0;
            feasible <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            result <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                packmen_positions[i] <= 4'd0;
                asterisk_positions[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        busy <= 1'b1;
                        cycle_count <= 8'd0;
                    end
                end

                INIT: begin
                    packmen_count <= 4'd0;
                    asterisk_count <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (field[i] == 2) begin
                            packmen_positions[packmen_count] <= i;
                            packmen_count <= packmen_count + 4'd1;
                        end else if (field[i] == 1) begin
                            asterisk_positions[asterisk_count] <= i;
                            asterisk_count <= asterisk_count + 4'd1;
                        end
                    end
                    state <= BINARY_SEARCH;
                end

                BINARY_SEARCH: begin
                    if (low > high) begin
                        result <= mid;
                        state <= FINISH;
                    end else begin
                        mid <= (low + high) >> 1;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    feasible <= 1'b1;
                    eaten_asterisks <= 4'd0;
                    current_asterisk <= 4'd0;
                    for (i = 0; i < packmen_count; i = i + 1) begin
                        temp_packman <= packmen_positions[i];
                        for (j = current_asterisk; j < asterisk_count; j = j + 1) begin
                            temp_asterisk <= asterisk_positions[j];
                            distance <= (temp_packman > temp_asterisk) ? (temp_packman - temp_asterisk) : (temp_asterisk - temp_packman);
                            if (distance <= mid) begin
                                eaten_asterisks <= eaten_asterisks + 4'd1;
                                current_asterisk <= j + 4'd1;
                            end else begin
                                break;
                            end
                        end
                    end
                    if (eaten_asterisks == asterisk_count) begin
                        feasible <= 1'b1;
                    end else begin
                        feasible <= 1'b0;
                    end
                    if (feasible) begin
                        high <= mid - 8'd1;
                    end else begin
                        low <= mid + 8'd1;
                    end
                    state <= BINARY_SEARCH;
                end

                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= max_cycles) begin
                state <= IDLE;
                busy <= 1'b0;
            end
        end
    end

endmodule