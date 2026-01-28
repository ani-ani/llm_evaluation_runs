module LCD_Pixel_Activator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire pulse_direction,
    input wire [15:0] pulse_time,
    input wire [15:0] pulse_length,
    input wire [4:0] pulse_wire,
    input wire valid_i,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD_PULSES = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Pulse storage registers
    reg [15:0] h_time [0:15];
    reg [15:0] h_len [0:15];
    reg h_wire_valid [0:15];
    reg [15:0] v_time [0:15];
    reg [15:0] v_len [0:15];
    reg v_wire_valid [0:15];

    // FSM state and counters
    reg [1:0] state;
    reg [3:0] h_idx;
    reg [3:0] v_idx;
    reg [31:0] count;
    reg [7:0] pulse_counter;
    localparam [7:0] MAX_PULSES = 8'd32;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            pulse_counter <= 8'd0;
            count <= 32'd0;
            h_idx <= 4'd0;
            v_idx <= 4'd0;

            // Initialize pulse storage
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                h_time[i] <= 16'd0;
                h_len[i] <= 16'd0;
                h_wire_valid[i] <= 1'b0;
                v_time[i] <= 16'd0;
                v_len[i] <= 16'd0;
                v_wire_valid[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD_PULSES;
                        busy <= 1'b1;
                        pulse_counter <= 8'd0;
                    end
                end

                LOAD_PULSES: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    if (valid_i && pulse_counter < MAX_PULSES) begin
                        if (!pulse_direction) begin // Horizontal
                            h_time[pulse_wire - 1] <= pulse_time;
                            h_len[pulse_wire - 1] <= pulse_length;
                            h_wire_valid[pulse_wire - 1] <= 1'b1;
                        end else begin // Vertical
                            v_time[pulse_wire - 1] <= pulse_time;
                            v_len[pulse_wire - 1] <= pulse_length;
                            v_wire_valid[pulse_wire - 1] <= 1'b1;
                        end
                        pulse_counter <= pulse_counter + 8'd1;
                    end
                    if (!valid_i || pulse_counter >= MAX_PULSES) begin
                        state <= CALCULATE;
                        h_idx <= 4'd0;
                        v_idx <= 4'd0;
                        count <= 32'd0;
                    end
                end

                CALCULATE: begin
                    busy <= 1'b1;
                    done <= 1'b0;

                    // Calculate overlap for current h_idx and v_idx
                    reg [15:0] h_start, h_end, v_start, v_end;
                    reg overlap;

                    if (h_wire_valid[h_idx] && v_wire_valid[v_idx]) begin
                        h_start = h_time[h_idx] + h_idx;
                        h_end = h_start + h_len[h_idx];
                        v_start = v_time[v_idx] + v_idx;
                        v_end = v_start + v_len[v_idx];

                        overlap = (h_start < v_end) && (v_start < h_end);
                        if (overlap) begin
                            count <= count + 32'd1;
                        end
                    end

                    // Update indices
                    if (v_idx == 4'd15) begin
                        if (h_idx == 4'd15) begin
                            state <= DONE_STATE;
                            result <= count;
                        end else begin
                            h_idx <= h_idx + 4'd1;
                            v_idx <= 4'd0;
                        end
                    end else begin
                        v_idx <= v_idx + 4'd1;
                    end
                end

                DONE_STATE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule