module max_satisfied_people #(
    parameter NUM_PEOPLE = 8,
    parameter DATA_WIDTH = 16,
    parameter MAX_SUM = 10000
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] a0, a1, a2, a3, a4, a5, a6, a7,
    input wire [DATA_WIDTH-1:0] b0, b1, b2, b3, b4, b5, b6, b7,
    input wire [DATA_WIDTH-1:0] c0, c1, c2, c3, c4, c5, c6, c7,
    output reg [3:0] result,
    output reg done
);
    
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP = 3'd2;
    localparam [2:0] SCAN = 3'd3;
    localparam [2:0] CHECK = 3'd4;
    localparam [2:0] POPCOUNT = 3'd5;
    localparam [2:0] UPDATE = 3'd6;
    
    reg [2:0] state, next_state;
    reg [7:0] mask;
    reg [3:0] best_count;
    reg [DATA_WIDTH-1:0] max_a, max_b, max_c;
    reg [DATA_WIDTH:0] sum;
    reg [3:0] popcount;
    reg [2:0] scan_idx;
    reg [DATA_WIDTH-1:0] reg_a [0:NUM_PEOPLE-1];
    reg [DATA_WIDTH-1:0] reg_b [0:NUM_PEOPLE-1];
    reg [DATA_WIDTH-1:0] reg_c [0:NUM_PEOPLE-1];
    reg [3:0] popcount_rom [0:255];
    integer i;
    
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            popcount_rom[i] = 0;
            if (i[0]) popcount_rom[i] = popcount_rom[i] + 1;
            if (i[1]) popcount_rom[i] = popcount_rom[i] + 1;
            if (i[2]) popcount_rom[i] = popcount_rom[i] + 1;
            if (i[3]) popcount_rom[i] = popcount_rom[i] + 1;
            if (i[4]) popcount_rom[i] = popcount_rom[i] + 1;
            if (i[5]) popcount_rom[i] = popcount_rom[i] + 1;
            if (i[6]) popcount_rom[i] = popcount_rom[i] + 1;
            if (i[7]) popcount_rom[i] = popcount_rom[i] + 1;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 8'd0;
            best_count <= 4'd0;
            max_a <= {DATA_WIDTH{1'b0}};
            max_b <= {DATA_WIDTH{1'b0}};
            max_c <= {DATA_WIDTH{1'b0}};
            sum <= {DATA_WIDTH+1{1'b0}};
            popcount <= 4'd0;
            done <= 1'b0;
            scan_idx <= 3'd0;
            for (i = 0; i < NUM_PEOPLE; i = i + 1) begin
                reg_a[i] <= {DATA_WIDTH{1'b0}};
                reg_b[i] <= {DATA_WIDTH{1'b0}};
                reg_c[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        reg_a[0] <= a0; reg_a[1] <= a1; reg_a[2] <= a2; reg_a[3] <= a3;
                        reg_a[4] <= a4; reg_a[5] <= a5; reg_a[6] <= a6; reg_a[7] <= a7;
                        reg_b[0] <= b0; reg_b[1] <= b1; reg_b[2] <= b2; reg_b[3] <= b3;
                        reg_b[4] <= b4; reg_b[5] <= b5; reg_b[6] <= b6; reg_b[7] <= b7;
                        reg_c[0] <= c0; reg_c[1] <= c1; reg_c[2] <= c2; reg_c[3] <= c3;
                        reg_c[4] <= c4; reg_c[5] <= c5; reg_c[6] <= c6; reg_c[7] <= c7;
                        best_count <= 4'd0;
                        done <= 1'b0;
                    end
                end
                INIT: begin
                    mask <= 8'd0;
                    scan_idx <= 3'd0;
                    max_a <= {DATA_WIDTH{1'b0}};
                    max_b <= {DATA_WIDTH{1'b0}};
                    max_c <= {DATA_WIDTH{1'b0}};
                end
                LOOP: begin
                    if (mask == 8'd255) begin
                        done <= 1'b1;
                    end else begin
                        scan_idx <= 3'd0;
                        max_a <= {DATA_WIDTH{1'b0}};
                        max_b <= {DATA_WIDTH{1'b0}};
                        max_c <= {DATA_WIDTH{1'b0}};
                    end
                end
                SCAN: begin
                    if (mask[scan_idx]) begin
                        if (reg_a[scan_idx] > max_a) max_a <= reg_a[scan_idx];
                        if (reg_b[scan_idx] > max_b) max_b <= reg_b[scan_idx];
                        if (reg_c[scan_idx] > max_c) max_c <= reg_c[scan_idx];
                    end
                    scan_idx <= scan_idx + 3'd1;
                end
                CHECK: sum <= max_a + max_b + max_c;
                POPCOUNT: popcount <= popcount_rom[mask];
                UPDATE: begin
                    if (sum <= MAX_SUM && popcount > best_count) best_count <= popcount;
                    mask <= mask + 8'd1;
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT; else next_state = IDLE;
            INIT: next_state = LOOP;
            LOOP: if (mask == 8'd255) next_state = IDLE; else next_state = SCAN;
            SCAN: if (scan_idx == NUM_PEOPLE-1) next_state = CHECK; else next_state = SCAN;
            CHECK: next_state = POPCOUNT;
            POPCOUNT: next_state = UPDATE;
            UPDATE: next_state = LOOP;
            default: next_state = IDLE;
        endcase
    end
    
    assign result = best_count;
endmodule