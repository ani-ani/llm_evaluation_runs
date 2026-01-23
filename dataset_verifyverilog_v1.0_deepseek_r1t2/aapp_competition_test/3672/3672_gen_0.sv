module coexist_checker #(
    parameter MAX_M = 8,
    parameter MAX_N = 8,
    parameter IDX_WIDTH = 3,
    parameter N_WIDTH = 3
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N_WIDTH-1:0] m,
    input wire [N_WIDTH-1:0] n,
    input wire [IDX_WIDTH-1:0] edge_u_0,
    input wire [IDX_WIDTH-1:0] edge_u_1,
    input wire [IDX_WIDTH-1:0] edge_u_2,
    input wire [IDX_WIDTH-1:0] edge_u_3,
    input wire [IDX_WIDTH-1:0] edge_u_4,
    input wire [IDX_WIDTH-1:0] edge_u_5,
    input wire [IDX_WIDTH-1:0] edge_u_6,
    input wire [IDX_WIDTH-1:0] edge_u_7,
    input wire [IDX_WIDTH-1:0] edge_v_0,
    input wire [IDX_WIDTH-1:0] edge_v_1,
    input wire [IDX_WIDTH-1:0] edge_v_2,
    input wire [IDX_WIDTH-1:0] edge_v_3,
    input wire [IDX_WIDTH-1:0] edge_v_4,
    input wire [IDX_WIDTH-1:0] edge_v_5,
    input wire [IDX_WIDTH-1:0] edge_v_6,
    input wire [IDX_WIDTH-1:0] edge_v_7,
    output reg done,
    output reg result
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CLEAR_COLORS = 3'd1;
localparam [2:0] INIT = 3'd2;
localparam [2:0] SCAN_PASS = 3'd3;
localparam [2:0] CHECK_CHANGED = 3'd4;
localparam [2:0] DONE_YES = 3'd5;
localparam [2:0] DONE_NO = 3'd6;

// Internal registers
reg [2:0] state, next_state;
reg [IDX_WIDTH-1:0] clear_idx;
reg [IDX_WIDTH-1:0] pass_counter;
reg [IDX_WIDTH-1:0] edge_idx;
reg changed;
reg conflict;
reg [N_WIDTH-1:0] m_reg;
reg [N_WIDTH-1:0] n_reg;
reg [1:0] color [0:MAX_M-1]; // 0=uncolored, 1=colorA, 2=colorB

// Current edge selection
wire [IDX_WIDTH-1:0] current_u;
wire [IDX_WIDTH-1:0] current_v;
assign current_u = (edge_idx == 3'd0) ? edge_u_0 :
                   (edge_idx == 3'd1) ? edge_u_1 :
                   (edge_idx == 3'd2) ? edge_u_2 :
                   (edge_idx == 3'd3) ? edge_u_3 :
                   (edge_idx == 3'd4) ? edge_u_4 :
                   (edge_idx == 3'd5) ? edge_u_5 :
                   (edge_idx == 3'd6) ? edge_u_6 :
                   edge_u_7;
assign current_v = (edge_idx == 3'd0) ? edge_v_0 :
                   (edge_idx == 3'd1) ? edge_v_1 :
                   (edge_idx == 3'd2) ? edge_v_2 :
                   (edge_idx == 3'd3) ? edge_v_3 :
                   (edge_idx == 3'd4) ? edge_v_4 :
                   (edge_idx == 3'd5) ? edge_v_5 :
                   (edge_idx == 3'd6) ? edge_v_6 :
                   edge_v_7;

// Current colors
wire [1:0] cu = color[current_u];
wire [1:0] cv = color[current_v];

integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 1'b0;
        clear_idx <= {IDX_WIDTH{1'b0}};
        pass_counter <= {IDX_WIDTH{1'b0}};
        edge_idx <= {IDX_WIDTH{1'b0}};
        changed <= 1'b0;
        conflict <= 1'b0;
        m_reg <= {N_WIDTH{1'b0}};
        n_reg <= {N_WIDTH{1'b0}};
        for (i = 0; i < MAX_M; i = i + 1) begin
            color[i] <= 2'b00;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                result <= 1'b0;
                if (start) begin
                    state <= CLEAR_COLORS;
                    clear_idx <= {IDX_WIDTH{1'b0}};
                end
            end

            CLEAR_COLORS: begin
                if (clear_idx < MAX_M) begin
                    color[clear_idx] <= 2'b00;
                    clear_idx <= clear_idx + 1'b1;
                end else begin
                    state <= INIT;
                end
            end

            INIT: begin
                m_reg <= m;
                n_reg <= n;
                pass_counter <= {IDX_WIDTH{1'b0}};
                changed <= 1'b0;
                conflict <= 1'b0;
                edge_idx <= {IDX_WIDTH{1'b0}};
                if (n == {N_WIDTH{1'b0}}) begin
                    state <= DONE_YES;
                end else begin
                    state <= SCAN_PASS;
                end
            end

            SCAN_PASS: begin
                if (!conflict) begin
                    if (current_u == current_v) begin
                        conflict <= 1'b1;
                    end else if (cu == 2'b00 && cv == 2'b00) begin
                        color[current_u] <= 2'b01;
                        color[current_v] <= 2'b10;
                        changed <= 1'b1;
                    end else if (cu == 2'b00 && cv != 2'b00) begin
                        color[current_u] <= (cv == 2'b01) ? 2'b10 : 2'b01;
                        changed <= 1'b1;
                    end else if (cv == 2'b00 && cu != 2'b00) begin
                        color[current_v] <= (cu == 2'b01) ? 2'b10 : 2'b01;
                        changed <= 1'b1;
                    end else if (cu == cv) begin
                        conflict <= 1'b1;
                    end
                end

                if (edge_idx < n_reg - 1'b1) begin
                    edge_idx <= edge_idx + 1'b1;
                end else begin
                    state <= CHECK_CHANGED;
                    edge_idx <= {IDX_WIDTH{1'b0}};
                end
            end

            CHECK_CHANGED: begin
                if (conflict) begin
                    state <= DONE_NO;
                end else if (changed) begin
                    changed <= 1'b0;
                    pass_counter <= pass_counter + 1'b1;
                    if (pass_counter + 1'b1 >= m_reg) begin
                        state <= DONE_YES;
                    end else begin
                        state <= SCAN_PASS;
                    end
                end else begin
                    state <= DONE_YES;
                end
            end

            DONE_YES: begin
                done <= 1'b1;
                result <= 1'b1;
                state <= IDLE;
            end

            DONE_NO: begin
                done <= 1'b1;
                result <= 1'b0;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule