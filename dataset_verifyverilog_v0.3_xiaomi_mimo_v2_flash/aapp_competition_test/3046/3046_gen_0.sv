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
localparam [9:0] POINT_WIDTH = 2*DATA_WIDTH + 1 + IDX_WIDTH;
reg [POINT_WIDTH-1:0] points [0:2*N-1];

// Stack
reg [IDX_WIDTH-1:0] stack [0:N-1];
reg [IDX_WIDTH-1:0] sp;

// Counters
reg [3:0] load_count;
reg [3:0] i_count;
reg [3:0] j_count;
reg [3:0] idx_proc;

// Helper macros (as combinational signals)
wire [DATA_WIDTH-1:0] point_r_j;
wire [DATA_WIDTH-1:0] point_r_j1;
wire [DATA_WIDTH-1:0] point_c_j;
wire [DATA_WIDTH-1:0] point_c_j1;
wire point_type_j;
wire point_type_j1;
wire [IDX_WIDTH-1:0] point_idx_j;
wire [IDX_WIDTH-1:0] point_idx_j1;

assign point_r_j = points[j_count][POINT_WIDTH-1 : POINT_WIDTH-DATA_WIDTH];
assign point_r_j1 = points[j_count+1][POINT_WIDTH-1 : POINT_WIDTH-DATA_WIDTH];
assign point_c_j = points[j_count][POINT_WIDTH-DATA_WIDTH-1 : POINT_WIDTH-2*DATA_WIDTH];
assign point_c_j1 = points[j_count+1][POINT_WIDTH-DATA_WIDTH-1 : POINT_WIDTH-2*DATA_WIDTH];
assign point_type_j = points[j_count][POINT_WIDTH-2*DATA_WIDTH-1];
assign point_type_j1 = points[j_count+1][POINT_WIDTH-2*DATA_WIDTH-1];
assign point_idx_j = points[j_count][POINT_WIDTH-2*DATA_WIDTH-2 : 0];
assign point_idx_j1 = points[j_count+1][POINT_WIDTH-2*DATA_WIDTH-2 : 0];

// Comparator for bubble sort
wire sort_greater;
assign sort_greater = (point_r_j > point_r_j1) ||
                      (point_r_j == point_r_j1 && point_c_j > point_c_j1) ||
                      (point_r_j == point_r_j1 && point_c_j == point_c_j1 && point_type_j > point_type_j1) ||
                      (point_r_j == point_r_j1 && point_c_j == point_c_j1 && point_type_j == point_type_j1 && point_idx_j > point_idx_j1);

// Current point fields (combinational from idx_proc)
wire [DATA_WIDTH-1:0] current_r;
wire [DATA_WIDTH-1:0] current_c;
wire current_type;
wire [IDX_WIDTH-1:0] current_idx;

assign current_r = points[idx_proc][POINT_WIDTH-1 : POINT_WIDTH-DATA_WIDTH];
assign current_c = points[idx_proc][POINT_WIDTH-DATA_WIDTH-1 : POINT_WIDTH-2*DATA_WIDTH];
assign current_type = points[idx_proc][POINT_WIDTH-2*DATA_WIDTH-1];
assign current_idx = points[idx_proc][POINT_WIDTH-2*DATA_WIDTH-2 : 0];

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        error <= 1'b0;
        sp <= 4'd0;
        load_count <= 4'd0;
        i_count <= 4'd0;
        j_count <= 4'd0;
        idx_proc <= 4'd0;
        // Initialize match array
        for (integer k = 0; k < N; k = k + 1) begin
            match[k] <= {IDX_WIDTH{1'b0}};
        end
        // Initialize points array
        for (integer k = 0; k < 2*N; k = k + 1) begin
            points[k] <= {POINT_WIDTH{1'b0}};
        end
        // Initialize stack
        for (integer k = 0; k < N; k = k + 1) begin
            stack[k] <= {IDX_WIDTH{1'b0}};
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                error <= 1'b0;
                if (start) begin
                    state <= LOAD;
                    load_count <= 4'd0;
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
                if (i_count < 2*N - 1) begin
                    if (j_count < 2*N - 1 - i_count) begin
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
                    if (current_type == 1'b0) begin
                        stack[sp] <= current_idx;
                        sp <= sp + 4'd1;
                    end else begin
                        if (sp == 4'd0) begin
                            error <= 1'b1;
                            state <= ERROR;
                        end else begin
                            sp <= sp - 4'd1;
                            if (tl_r[stack[sp-4'd1]] >= br_r[current_idx] || tl_c[stack[sp-4'd1]] >= br_c[current_idx]) begin
                                error <= 1'b1;
                                state <= ERROR;
                            end else begin
                                match[stack[sp-4'd1]] <= current_idx + 4'd1;
                            end
                        end
                    end
                    idx_proc <= idx_proc + 4'd1;
                end else begin
                    if (sp != 4'd0) begin
                        error <= 1'b1;
                        state <= ERROR;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
            end
            
            DONE, ERROR: begin
                // stay in these states
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule