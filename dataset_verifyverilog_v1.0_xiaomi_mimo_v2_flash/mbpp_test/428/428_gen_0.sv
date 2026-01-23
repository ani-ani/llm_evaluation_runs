module shell_sort (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg [7:0] sorted_0,
    output reg [7:0] sorted_1,
    output reg [7:0] sorted_2,
    output reg [7:0] sorted_3,
    output reg [7:0] sorted_4,
    output reg [7:0] sorted_5,
    output reg [7:0] sorted_6,
    output reg [7:0] sorted_7,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD       = 4'd1;
    localparam [3:0] GAP_LOOP   = 4'd2;
    localparam [3:0] INNER_LOOP = 4'd3;
    localparam [3:0] COMPARE    = 4'd4;
    localparam [3:0] SHIFT      = 4'd5;
    localparam [3:0] INSERT     = 4'd6;
    localparam [3:0] NEXT_I     = 4'd7;
    localparam [3:0] FINISH     = 4'd8;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] data [0:7];  // Working memory
    reg [2:0] gap;          // Gap size (0-4)
    reg [2:0] i;            // Outer loop index
    reg [2:0] j;            // Inner loop index
    reg [7:0] current_item; // Temp for insertion
    reg [7:0] cycle_count;   // To prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? LOAD : IDLE;
            LOAD:       next_state = GAP_LOOP;
            GAP_LOOP:   next_state = (gap > 3'd0) ? INNER_LOOP : FINISH;
            INNER_LOOP: next_state = (i < 3'd8) ? COMPARE : NEXT_I;
            COMPARE:    next_state = (j >= gap && data[j - gap] > current_item) ? SHIFT : INSERT;
            SHIFT:      next_state = COMPARE;
            INSERT:     next_state = NEXT_I;
            NEXT_I:     next_state = (i < 3'd7) ? INNER_LOOP : GAP_LOOP;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Data path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gap <= 3'd4;
            i <= 3'd0;
            j <= 3'd0;
            current_item <= 8'd0;
            cycle_count <= 8'd0;
            data[0] <= 8'd0;
            data[1] <= 8'd0;
            data[2] <= 8'd0;
            data[3] <= 8'd0;
            data[4] <= 8'd0;
            data[5] <= 8'd0;
            data[6] <= 8'd0;
            data[7] <= 8'd0;
            done <= 1'b0;
            sorted_0 <= 8'd0;
            sorted_1 <= 8'd0;
            sorted_2 <= 8'd0;
            sorted_3 <= 8'd0;
            sorted_4 <= 8'd0;
            sorted_5 <= 8'd0;
            sorted_6 <= 8'd0;
            sorted_7 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                LOAD: begin
                    data[0] <= arr_0;
                    data[1] <= arr_1;
                    data[2] <= arr_2;
                    data[3] <= arr_3;
                    data[4] <= arr_4;
                    data[5] <= arr_5;
                    data[6] <= arr_6;
                    data[7] <= arr_7;
                    gap <= 3'd4;
                    i <= 3'd0;
                end
                GAP_LOOP: begin
                    gap <= (gap >> 1);
                    i <= (gap >> 1);
                    cycle_count <= cycle_count + 8'd1;
                end
                INNER_LOOP: begin
                    current_item <= data[i];
                    j <= i;
                end
                SHIFT: begin
                    data[j] <= data[j - gap];
                    j <= j - gap;
                end
                INSERT: begin
                    data[j] <= current_item;
                end
                NEXT_I: begin
                    i <= i + 3'd1;
                end
                FINISH: begin
                    sorted_0 <= data[0];
                    sorted_1 <= data[1];
                    sorted_2 <= data[2];
                    sorted_3 <= data[3];
                    sorted_4 <= data[4];
                    sorted_5 <= data[5];
                    sorted_6 <= data[6];
                    sorted_7 <= data[7];
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule