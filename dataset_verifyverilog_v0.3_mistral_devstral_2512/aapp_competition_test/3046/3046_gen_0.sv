module rectangle_matcher #(
    parameter N = 8,
    parameter DATA_WIDTH = 16,
    parameter IDX_WIDTH = 4
) (
    input clk, rst_n, start,
    input [DATA_WIDTH-1:0] tl_r [0:N-1],
    input [DATA_WIDTH-1:0] tl_c [0:N-1],
    input [DATA_WIDTH-1:0] br_r [0:N-1],
    input [DATA_WIDTH-1:0] br_c [0:N-1],
    output reg [IDX_WIDTH-1:0] match [0:N-1],
    output reg done,
    output reg error
);

// Define states
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD = 3'd1;
localparam [2:0] SORT = 3'd2;
localparam [2:0] PROCESS = 3'd3;
localparam [2:0] DONE = 3'd4;
localparam [2:0] ERROR = 3'd5;
reg [2:0] state;

// Define point structure: {r, c, type, idx}
localparam POINT_WIDTH = 2*DATA_WIDTH + 1 + IDX_WIDTH;
reg [POINT_WIDTH-1:0] points [0:2*N-1];

// Stack
reg [IDX_WIDTH-1:0] stack [0:N-1];
reg [IDX_WIDTH-1:0] sp;

// Counters
reg [3:0] load_count;
reg [3:0] i_count;
reg [3:0] j_count;
reg [3:0] idx_proc;

// Helper macros
`define POINT_R(p) p[POINT_WIDTH-1 : POINT_WIDTH-DATA_WIDTH]
`define POINT_C(p) p[POINT_WIDTH-DATA_WIDTH-1 : POINT_WIDTH-2*DATA_WIDTH]
`define POINT_TYPE(p) p[POINT_WIDTH-2*DATA_WIDTH-1]
`define POINT_IDX(p) p[POINT_WIDTH-2*DATA_WIDTH-2 : 0]

// Comparator for bubble sort
wire sort_greater;
assign sort_greater = (`POINT_R(points[j_count]) > `POINT_R(points[j_count+1])) ||
                      (`POINT_R(points[j_count]) == `POINT_R(points[j_count+1]) && `POINT_C(points[j_count]) > `POINT_C(points[j_count+1])) ||
                      (`POINT_R(points[j_count]) == `POINT_R(points[j_count+1]) && `POINT_C(points[j_count]) == `POINT_C(points[j_count+1]) && `POINT_TYPE(points[j_count]) > `POINT_TYPE(points[j_count+1])) ||
                      (`POINT_R(points[j_count]) == `POINT_R(points[j_count+1]) && `POINT_C(points[j_count]) == `POINT_C(points[j_count+1]) && `POINT_TYPE(points[j_count]) == `POINT_TYPE(points[j_count+1]) && `POINT_IDX(points[j_count]) > `POINT_IDX(points[j_count+1]));

// Current point fields
wire [DATA_WIDTH-1:0] current_r = `POINT_R(points[idx_proc]);
wire [DATA_WIDTH-1:0] current_c = `POINT_C(points[idx_proc]);
wire current_type = `POINT_TYPE(points[idx_proc]);
wire [IDX_WIDTH-1:0] current_idx = `POINT_IDX(points[idx_proc]);

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        error <= 1'b0;
        match <= '{default:0};
        points <= '{default:0};
        stack <= '{default:0};
        sp <= 0;
        load_count <= 4'd0;
        i_count <= 4'd0;
        j_count <= 4'd0;
        idx_proc <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD;
                    load_count <= 4'd0;
                    done <= 1'b0;
                    error <= 1'b0;
                end
            end
            LOAD: begin
                if (load_count < 2*N) begin
                    if (load_count < N) begin
                        points[load_count] <= {tl_r[load_count], tl_c[load_count], 1'b0, load_count[IDX_WIDTH-1:0]};
                    end else begin
                        points[load_count] <= {br_r[load_count-N], br_c[load_count-N], 1'b1, (load_count-N)[IDX_WIDTH-1:0]};
                    end
                    load_count <= load_count + 4'd1;
                end else begin
                    state <= SORT;
                    i_count <= 4'd0;
                    j_count <= 4'd0;
                end
            end
            SORT: begin
                if (i_count < 2*N-1) begin
                    if (j_count < 2*N-1 - i_count) begin
                        if (sort_greater) begin
                            points[j_count] <= points[j_count+1];
                            points[j_count+1] <= points[j_count];
                        end
                        j_count <= j_count + 4'd1;
                    end else begin
                        j_count <= 4'd0;
                        i_count <= i_count + 4'd1;
                    end
                end else begin
                    state <= PROCESS;
                    idx_proc <= 4'd0;
                    sp <= 4'd0;
                end
            end
            PROCESS: begin
                if (idx_proc < 2*N) begin
                    if (current_type == 0) begin
                        stack[sp] <= current_idx;
                        sp <= sp + 4'd1;
                    end else begin
                        if (sp == 0) begin
                            error <= 1'b1;
                            state <= ERROR;
                        end else begin
                            sp <= sp - 4'd1;
                            if (tl_r[stack[sp]] >= br_r[current_idx] || tl_c[stack[sp]] >= br_c[current_idx]) begin
                                error <= 1'b1;
                                state <= ERROR;
                            end else begin
                                match[stack[sp]] <= current_idx + 4'd1;
                            end
                        end
                    end
                    idx_proc <= idx_proc + 4'd1;
                end else begin
                    if (sp != 0) begin
                        error <= 1'b1;
                        state <= ERROR;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
            end
            DONE, ERROR: begin
                // stay here
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule