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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] GAP_LOOP = 3'd2;
    localparam [2:0] INNER_LOOP = 3'd3;
    localparam [2:0] COMPARE = 3'd4;
    localparam [2:0] SHIFT = 3'd5;
    localparam [2:0] INSERT = 3'd6;
    localparam [2:0] NEXT_I = 3'd7;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] data [0:7];  // Working memory
    reg [2:0] gap;          // Gap size (0-4)
    reg [2:0] i;            // Outer loop index
    reg [2:0] j;            // Inner loop index
    reg [7:0] current_item; // Temp for insertion
    reg [2:0] gap_next;     // Next gap value

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
        end else begin
            state <= next_state;
            done <= (state == NEXT_I && i >= 8 && gap == 0) ? 1'b1 : 1'b0;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = GAP_LOOP;
            GAP_LOOP: next_state = (gap > 0) ? INNER_LOOP : IDLE;
            INNER_LOOP: next_state = (i < 8) ? COMPARE : NEXT_I;
            COMPARE: next_state = (j >= gap && data[j-gap] > current_item) ? SHIFT : INSERT;
            SHIFT: next_state = COMPARE;
            INSERT: next_state = NEXT_I;
            NEXT_I: begin
                if (i + 1 < 8) next_state = INNER_LOOP;
                else next_state = GAP_LOOP;
            end
            default: next_state = IDLE;
        endcase
    end

    // Data path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gap <= 3'd4;
            i <= 3'd0;
            j <= 3'd0;
            current_item <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    gap <= 3'd4;
                    i <= 3'd0;
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
                end
                GAP_LOOP: begin
                    gap <= gap >> 1;
                    i <= gap >> 1;
                end
                INNER_LOOP: begin
                    if (i < 8) begin
                        current_item <= data[i];
                        j <= i;
                    end
                end
                SHIFT: begin
                    data[j] <= data[j - gap];
                    j <= j - gap;
                end
                INSERT: begin
                    data[j] <= current_item;
                end
                NEXT_I: begin
                    i <= i + 1;
                end
            endcase
        end
    end

    // Output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sorted_0 <= 8'd0;
            sorted_1 <= 8'd0;
            sorted_2 <= 8'd0;
            sorted_3 <= 8'd0;
            sorted_4 <= 8'd0;
            sorted_5 <= 8'd0;
            sorted_6 <= 8'd0;
            sorted_7 <= 8'd0;
        end else if (state == NEXT_I && i >= 8 && gap == 0) begin
            sorted_0 <= data[0];
            sorted_1 <= data[1];
            sorted_2 <= data[2];
            sorted_3 <= data[3];
            sorted_4 <= data[4];
            sorted_5 <= data[5];
            sorted_6 <= data[6];
            sorted_7 <= data[7];
        end
    end

endmodule