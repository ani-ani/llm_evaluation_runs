module tram_scheduling (
   input clk,
   input rst_n,
   input start,
   input [7:0] s,
   input [7:0] num_stops,
   input [7:0] num_lines,
   input [7:0] t0 [0:7],
   input [7:0] p [0:7],
   input [7:0] d [0:7],
   input [2:0] u [0:7],
   input [2:0] v [0:7],
   output reg [7:0] latest_departure,
   output reg valid,
   output reg impossible
);

reg [7:0] s_reg;
reg [7:0] num_stops_reg;
reg [7:0] num_lines_reg;
reg [7:0] t0_reg [0:7];
reg [7:0] p_reg [0:7];
reg [7:0] d_reg [0:7];
reg [2:0] u_reg [0:7];
reg [2:0] v_reg [0:7];
reg [7:0] latest_arrival [0:7];
reg [7:0] iter_count;
reg [2:0] i;

localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam PROCESSING = 3'd2;
localparam DONE = 3'd3;
reg [2:0] state;

always @(posedge clk) begin
   if (!rst_n) begin
      s_reg <= 8'd0;
      num_stops_reg <=8'd0;
      num_lines_reg <=8'd0;
      t0_reg <=8'd0;
      p_reg <=8'd0;
      d_reg <=8'd0;
      u_reg <=3'd0;
      v_reg <=3'd0;
      latest_arrival <=8'd0;
      iter_count <=8'd0;
      state <= IDLE;
      valid <=1'b0;
      impossible <=1'b0;
      latest_departure <=8'd0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            s_reg <= s;
            num_stops_reg <= num_stops;
            num_lines_reg <= num_lines;
            t0_reg <= t0;
            p_reg <= p;
            d_reg <= d;
            u_reg <= u;
            v_reg <= v;
            state <= INIT;
         end
         valid <=1'b0;
         impossible <=1'b0;
         latest_departure <=8'd0;
      end else if (state == INIT) begin
         latest_arrival[0] <=8'd0;
         latest_arrival[1] <=8'd0;
         latest_arrival[2] <=8'd0;
         latest_arrival[3] <=8'd0;
         latest_arrival[4] <=8'd0;
         latest_arrival[5] <=8'd0;
         latest_arrival[6] <=8'd0;
         latest_arrival[7] <=8'd0;
         if (num_stops_reg >0 && num_stops_reg <=8) begin
             latest_arrival[num_stops_reg -1] <= s_reg;
         end
         iter_count <=8'd0;
         state <= PROCESSING;
         valid <=1'b0;
         impossible <=1'b0;
         latest_departure <=8'd0;
      end else if (state == PROCESSING) begin
         // Process each line (lines 0-7 with unrolled loops)
         // Line 0
         if (0 < num_lines_reg) begin
            integer u_i = u_reg[0];
            integer v_i = v_reg[0];
            integer t0_i = t0_reg[0];
            integer p_i = p_reg[0];
            integer d_i = d_reg[0];
            if (latest_arrival[v_i] >8'd0) begin
               integer target = latest_arrival[v_i] - d_i;
               if (target >= t0_i) begin
                  if (p_i !=8'd0) begin
                     integer k = (target - t0_i) / p_i;
                     integer departure_time = t0_i + (k * p_i);
                     if (departure_time > latest_arrival[u_i]) begin
                        latest_arrival[u_i] = departure_time;
                     end
                  end else begin
                     if (t0_i <= target) begin
                        integer departure_time = t0_i;
                        if (departure_time > latest_arrival[u_i]) begin
                           latest_arrival[u_i] = departure_time;
                        end
                     end
                  end
               end
            end
         end
         // Line 1
         if (1 < num_lines_reg) begin
            integer u_i = u_reg[1];
            integer v_i = v_reg[1];
            integer t0_i = t0_reg[1];
            integer p_i = p_reg[1];
            integer d_i = d_reg[1];
            if (latest_arrival[v_i] >8'd0) begin
               integer target = latest_arrival[v_i] - d_i;
               if (target >= t0_i) begin
                  if (p_i !=8'd0) begin
                     integer k = (target - t0_i) / p_i;
                     integer departure_time = t0_i + (k * p_i);
                     if (departure_time > latest_arrival[u_i]) begin
                        latest_arrival[u_i] = departure_time;
                     end
                  end else begin
                     if (t0_i <= target) begin
                        integer departure_time = t0_i;
                        if (departure_time > latest_arrival[u_i]) begin
                           latest_arrival[u_i] = departure_time;
                        end
                     end
                  end
               end
            end
         end
         // Line 2
         if (2 < num_lines_reg) begin
            integer u_i = u_reg[2];
            integer v_i = v_reg[2];
            integer t0_i = t0_reg[2];
            integer p_i = p_reg[2];
            integer d_i = d_reg[2];
            if (latest_arrival[v_i] >8'd0) begin
               integer target = latest_arrival[v_i] - d_i;
               if (target >= t0_i) begin
                  if (p_i !=8'd0) begin
                     integer k = (target - t0_i) / p_i;
                     integer departure_time = t0_i + (k * p_i);
                     if (departure_time > latest_arrival[u_i]) begin
                        latest_arrival[u_i] = departure_time;
                     end
                  end else begin
                     if (t0_i <= target) begin
                        integer departure_time = t0_i;
                        if (departure_time > latest_arrival[u_i]) begin
                           latest_arrival[u_i] = departure_time;
                        end
                     end
                  end
               end
            end
         end
         // Line 3
         if (3 < num_lines_reg) begin
            integer u_i = u_reg[3];
            integer v_i = v_reg[3];
            integer t0_i = t0_reg[3];
            integer p_i = p_reg[3];
            integer d_i = d_reg[3];
            if (latest_arrival[v_i] >8'd0) begin
               integer target = latest_arrival[v_i] - d_i;
               if (target >= t0_i) begin
                  if (p_i !=8'd0) begin
                     integer k = (target - t0_i) / p_i;
                     integer departure_time = t0_i + (k * p_i);
                     if (departure_time > latest_arrival[u_i]) begin
                        latest_arrival[u_i] = departure_time;
                     end
                  end else begin
                     if (t0_i <= target) begin
                        integer departure_time = t0_i;
                        if (departure_time > latest_arrival[u_i]) begin
                           latest_arrival[u_i] = departure_time;
                        end
                     end
                  end
               end
            end
         end
         // Line 4
         if (4 < num_lines_reg) begin
            integer u_i = u_reg[4];
            integer v_i = v_reg[4];
            integer t0_i = t0_reg[4];
            integer p_i = p_reg[4];
            integer d_i = d_reg[4];
            if (latest_arrival[v_i] >8'd0) begin
               integer target = latest_arrival[v_i] - d_i;
               if (target >= t0_i) begin
                  if (p_i !=8'd0) begin
                     integer k = (target - t0_i) / p_i;
                     integer departure_time = t0_i + (k * p_i);
                     if (departure_time > latest_arrival[u_i]) begin
                        latest_arrival[u_i] = departure_time;
                     end
                  end else begin
                     if (t0_i <= target) begin
                        integer departure_time = t0_i;
                        if (departure_time > latest_arrival[u_i]) begin
                           latest_arrival[u_i] = departure_time;
                        end
                     end
                  end
               end
            end
         end
         // Line 5
         if (5 < num_lines_reg) begin
            integer u_i = u_reg[5];
            integer v_i = v_reg[5];
            integer t0_i = t0_reg[5];
            integer p_i = p_reg[5];
            integer d_i = d_reg[5];
            if (latest_arrival[v_i] >8'd0) begin
               integer target = latest_arrival[v_i] - d_i;
               if (target >= t0_i) begin
                  if (p_i !=8'd0) begin
                     integer k = (target - t0_i) / p_i;
                     integer departure_time = t0_i + (k * p_i);
                     if (departure_time > latest_arrival[u_i]) begin
                        latest_arrival[u_i] = departure_time;
                     end
                  end else begin
                     if (t0_i <= target) begin
                        integer departure_time = t0_i;
                        if (departure_time > latest_arrival[u_i]) begin
                           latest_arrival[u_i] = departure_time;
                        end
                     end
                  end
               end
            end
         end
         // Line 6
         if (6 < num_lines_reg) begin
            integer u_i = u_reg[6];
            integer v_i = v_reg[6];
            integer t0_i = t0_reg[6];
            integer p_i = p_reg[6];
            integer d_i = d_reg[6];
            if (latest_arrival[v_i] >8'd0) begin
               integer target = latest_arrival[v_i] - d_i;
               if (target >= t0_i) begin
                  if (p_i !=8'd0) begin
                     integer k = (target - t0_i) / p_i;
                     integer departure_time = t0_i + (k * p_i);
                     if (departure_time > latest_arrival[u_i]) begin
                        latest_arrival[u_i] = departure_time;
                     end
                  end else begin
                     if (t0_i <= target) begin
                        integer departure_time = t0_i;
                        if (departure_time > latest_arrival[u_i]) begin
                           latest_arrival[u_i] = departure_time;
                        end
                     end
                  end
               end
            end
         end
         // Line 7
         if (7 < num_lines_reg) begin
            integer u_i = u_reg[7];
            integer v_i = v_reg[7];
            integer t0_i = t0_reg[7];
            integer p_i = p_reg[7];
            integer d_i = d_reg[7];
            if (latest_arrival[v_i] >8'd0) begin
               integer target = latest_arrival[v_i] - d_i;
               if (target >= t0_i) begin
                  if (p_i !=8'd0) begin
                     integer k = (target - t0_i) / p_i;
                     integer departure_time = t0_i + (k * p_i);
                     if (departure_time > latest_arrival[u_i]) begin
                        latest_arrival[u_i] = departure_time;
                     end
                  end else begin
                     if (t0_i <= target) begin
                        integer departure_time = t0_i;
                        if (departure_time > latest_arrival[u_i]) begin
                           latest_arrival[u_i] = departure_time;
                        end
                     end
                  end
               end
            end
         end
         iter_count <= iter_count +1;
         if (iter_count ==8) begin
             state <= DONE;
         end
         valid <=1'b0;
         impossible <=1'b0;
         latest_departure <=8'd0;
      end else if (state == DONE) begin
         if (num_stops_reg ==1) begin
             latest_departure <= s_reg;
             valid <=1'b1;
             impossible <=1'b0;
         end else begin
             if (latest_arrival[0] >8'd0) begin
                 latest_departure <= latest_arrival[0];
                 valid <=1'b1;
                 impossible <=1'b0;
             end else begin
                 valid <=1'b0;
                 impossible <=1'b1;
             end
         end
      end
   end
endmodule