module fog_catcher #(
    parameter MAX_FOGS = 8,
    parameter MAX_NETS = 8,
    parameter COORD_WIDTH = 16,
    parameter DAY_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [DAY_WIDTH-1:0] fog_day [0:MAX_FOGS-1],
    input wire [COORD_WIDTH-1:0] fog_left [0:MAX_FOGS-1],
    input wire [COORD_WIDTH-1:0] fog_right [0:MAX_FOGS-1],
    input wire [COORD_WIDTH-1:0] fog_height [0:MAX_FOGS-1],
    input wire [4:0] fog_valid_count,
    
    output reg [7:0] missed_count,
    output reg done
);

localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD_FOG = 3'd1;
localparam [2:0] CHECK_DAY = 3'd2;
localparam [2:0] CHECK_COVERAGE = 3'd3;
localparam [2:0] ADD_NET = 3'd4;
localparam [2:0] NEXT_FOG = 3'd5;
localparam [2:0] DONE_STATE = 3'd6;

reg [2:0] state, next_state;
reg [4:0] fog_idx;
reg [DAY_WIDTH-1:0] current_day;

reg [COORD_WIDTH-1:0] net_left [0:MAX_NETS-1];
reg [COORD_WIDTH-1:0] net_right [0:MAX_NETS-1];
reg [COORD_WIDTH-1:0] net_height [0:MAX_NETS-1];
reg [4:0] net_count;

reg [DAY_WIDTH-1:0] curr_fog_day;
reg [COORD_WIDTH-1:0] curr_fog_left;
reg [COORD_WIDTH-1:0] curr_fog_right;
reg [COORD_WIDTH-1:0] curr_fog_height;

function automatic logic is_covered;
    input [COORD_WIDTH-1:0] l, r, h;
    integer i;
    begin
        is_covered = 1'b0;
        for (i = 0; i < MAX_NETS; i = i + 1) begin
            if (i < net_count) begin
                if (net_left[i] <= l && net_right[i] >= r && net_height[i] >= h) begin
                    is_covered = 1'b1;
                end
            end
        end
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin : async_reset
        integer i;
        state <= IDLE;
        fog_idx <= 5'd0;
        missed_count <= 8'd0;
        net_count <= 5'd0;
        done <= 1'b0;
        current_day <= {DAY_WIDTH{1'b0}};
        for (i = 0; i < MAX_NETS; i = i + 1) begin
            net_left[i] <= {COORD_WIDTH{1'b0}};
            net_right[i] <= {COORD_WIDTH{1'b0}};
            net_height[i] <= {COORD_WIDTH{1'b0}};
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    fog_idx <= 5'd0;
                    missed_count <= 8'd0;
                    net_count <= 5'd0;
                    current_day <= {DAY_WIDTH{1'b0}};
                    state <= LOAD_FOG;
                end
            end
            
            LOAD_FOG: begin
                if (fog_idx < fog_valid_count) begin
                    curr_fog_day <= fog_day[fog_idx];
                    curr_fog_left <= fog_left[fog_idx];
                    curr_fog_right <= fog_right[fog_idx];
                    curr_fog_height <= fog_height[fog_idx];
                    state <= CHECK_DAY;
                end else begin
                    state <= DONE_STATE;
                end
            end
            
            CHECK_DAY: begin
                if (fog_idx == 5'd0) begin
                    current_day <= curr_fog_day;
                end else if (curr_fog_day != current_day) begin
                    current_day <= curr_fog_day;
                    net_count <= 5'd0;
                end
                state <= CHECK_COVERAGE;
            end
            
            CHECK_COVERAGE: begin
                if (!is_covered(curr_fog_left, curr_fog_right, curr_fog_height)) begin
                    missed_count <= missed_count + 8'd1;
                    state <= ADD_NET;
                end else begin
                    state <= NEXT_FOG;
                end
            end
            
            ADD_NET: begin
                if (net_count < MAX_NETS) begin
                    net_left[net_count] <= curr_fog_left;
                    net_right[net_count] <= curr_fog_right;
                    net_height[net_count] <= curr_fog_height;
                    net_count <= net_count + 5'd1;
                end
                state <= NEXT_FOG;
            end
            
            NEXT_FOG: begin
                fog_idx <= fog_idx + 5'd1;
                state <= LOAD_FOG;
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                if (!start) state <= IDLE;
                else state <= DONE_STATE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule