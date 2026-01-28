module fog_catcher #(
    parameter MAX_FOGS = 8,
    parameter MAX_NETS = 8,
    parameter COORD_WIDTH = 16,
    parameter DAY_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Fog data inputs - array of signals for each fog parameter
    input wire [DAY_WIDTH-1:0] fog_day [0:MAX_FOGS-1],
    input wire [COORD_WIDTH-1:0] fog_left [0:MAX_FOGS-1],
    input wire [COORD_WIDTH-1:0] fog_right [0:MAX_FOGS-1],
    input wire [COORD_WIDTH-1:0] fog_height [0:MAX_FOGS-1],
    input wire [4:0] fog_valid_count,
    
    output reg [7:0] missed_count,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD_FOG = 3'd1;
localparam [2:0] CHECK_DAY = 3'd2;
localparam [2:0] CHECK_COVERAGE = 3'd3;
localparam [2:0] ADD_NET = 3'd4;
localparam [2:0] NEXT_FOG = 3'd5;
localparam [2:0] DONE = 3'd6;

// Internal state
reg [2:0] state;
reg [2:0] next_state;
reg [4:0] fog_idx;
reg [DAY_WIDTH-1:0] current_day;

// Net storage - stored as rectangles from ground (y=0) to height
reg [COORD_WIDTH-1:0] net_left [0:MAX_NETS-1];
reg [COORD_WIDTH-1:0] net_right [0:MAX_NETS-1];
reg [COORD_WIDTH-1:0] net_height [0:MAX_NETS-1];
reg [4:0] net_count;

// Current fog being processed
reg [DAY_WIDTH-1:0] curr_fog_day;
reg [COORD_WIDTH-1:0] curr_fog_left;
reg [COORD_WIDTH-1:0] curr_fog_right;
reg [COORD_WIDTH-1:0] curr_fog_height;

// Combinational signal for coverage check
reg is_covered;
integer i;

always @(*) begin
    is_covered = 1'b0;
    for (i = 0; i < MAX_NETS; i = i + 1) begin
        if (i < net_count) begin
            // Net covers fog if fog is contained within net rectangle
            if (net_left[i] <= curr_fog_left && net_right[i] >= curr_fog_right && net_height[i] >= curr_fog_height) begin
                is_covered = 1'b1;
            end
        end
    end
end

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        fog_idx <= 0;
        missed_count <= 8'd0;
        net_count <= 0;
        done <= 1'b0;
        current_day <= 0;
        curr_fog_day <= 0;
        curr_fog_left <= 0;
        curr_fog_right <= 0;
        curr_fog_height <= 0;
    end else begin
        state <= next_state;
        
        case (next_state)
            IDLE: begin
                fog_idx <= 0;
                missed_count <= 8'd0;
                net_count <= 0;
                current_day <= 0;
                done <= 1'b0;
            end
            
            LOAD_FOG: begin
                if (fog_idx < fog_valid_count) begin
                    curr_fog_day <= fog_day[fog_idx];
                    curr_fog_left <= fog_left[fog_idx];
                    curr_fog_right <= fog_right[fog_idx];
                    curr_fog_height <= fog_height[fog_idx];
                end
            end
            
            CHECK_DAY: begin
                if (fog_idx == 5'd0) begin
                    current_day <= curr_fog_day;
                end else if (curr_fog_day != current_day) begin
                    current_day <= curr_fog_day;
                    net_count <= 0;
                end
            end
            
            CHECK_COVERAGE: begin
                if (!is_covered) begin
                    missed_count <= missed_count + 8'd1;
                end
            end
            
            ADD_NET: begin
                if (net_count < MAX_NETS) begin
                    net_left[net_count] <= curr_fog_left;
                    net_right[net_count] <= curr_fog_right;
                    net_height[net_count] <= curr_fog_height;
                    net_count <= net_count + 1;
                end
            end
            
            NEXT_FOG: begin
                fog_idx <= fog_idx + 1;
            end
            
            DONE: begin
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) begin
                next_state = LOAD_FOG;
            end else begin
                next_state = IDLE;
            end
        end
        
        LOAD_FOG: begin
            if (fog_idx < fog_valid_count) begin
                next_state = CHECK_DAY;
            end else begin
                next_state = DONE;
            end
        end
        
        CHECK_DAY: begin
            next_state = CHECK_COVERAGE;
        end
        
        CHECK_COVERAGE: begin
            if (!is_covered) begin
                next_state = ADD_NET;
            end else begin
                next_state = NEXT_FOG;
            end
        end
        
        ADD_NET: begin
            next_state = NEXT_FOG;
        end
        
        NEXT_FOG: begin
            next_state = LOAD_FOG;
        end
        
        DONE: begin
            if (!start) begin
                next_state = IDLE;
            end else begin
                next_state = DONE;
            end
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule