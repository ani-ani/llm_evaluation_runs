module train_path_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_stations,
  input [4:0] num_trains,
  input [3:0] origin_idx,
  input [3:0] dest_idx,
  input [15:0] train_data [15:0],
  output reg [31:0] min_time,
  output reg done,
  output reg impossible
);

localparam [31:0] INF = 32'hFFFF_FFFF;
localparam [31:0] ZERO = 32'h0;

typedef enum logic [1:0] {IDLE, INIT, RELAX, DONE} state_t;

reg [1:0] state_reg, state_next;
reg [3:0] relax_counter;
reg [31:0] distances [0:7];
reg [31:0] next_distances [0:7];

reg [3:0] train_src [0:15];
reg [3:0] train_dst [0:15];
reg [5:0] train_depart [0:15];
reg [8:0] train_time [0:15];
reg [6:0] train_prob [0:15];
reg [6:0] train_delay [0:15];

wire [255:0] train_data_all = {train_data[15], train_data[14], train_data[13], train_data[12],
                               train_data[11], train_data[10], train_data[9], train_data[8],
                               train_data[7], train_data[6], train_data[5], train_data[4],
                               train_data[3], train_data[2], train_data[1], train_data[0]};

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state_reg <= IDLE;
    relax_counter <= 0;
    done <= 0;
    impossible <= 0;
    for (int i=0; i<8; i=i+1) distances[i] <= INF;
  end else begin
    state_reg <= state_next;
    if (state_reg == RELAX) begin
      relax_counter <= relax_counter + 1;
      for (int i=0; i<8; i=i+1) distances[i] <= next_distances[i];
    end else if (state_reg == DONE) begin
      done <= 1;
      if (distances[dest_idx] == INF) impossible <= 1;
      else min_time <= distances[dest_idx];
    end else begin
      relax_counter <= 0;
      done <= 0;
      impossible <= 0;
    end
  end
end

always_comb begin
  state_next = state_reg;
  case (state_reg)
    IDLE: if (start) state_next = INIT;
    INIT: state_next = RELAX;
    RELAX: if (relax_counter == 15) state_next = DONE;
    DONE: state_next = IDLE;
  endcase
end

always_comb begin
  for (int i=0; i<8; i=i+1) next_distances[i] = distances[i];
  if (state_reg == RELAX) begin
    for (int i=0; i<16; i=i+1) begin
      if (i < num_trains) begin
        automatic logic [3:0] src = train_src[i];
        automatic logic [3:0] dst = train_dst[i];
        automatic logic [31:0] base_time = train_time[i] << 16;
        automatic logic [31:0] half_delay = (train_delay[i] + 1) * 32768;
        automatic logic [31:0] term1 = (100 - train_prob[i]) * base_time;
        automatic logic [31:0] term2 = train_prob[i] * (base_time + half_delay);
        automatic logic [31:0] E = (term1 + term2) / 100;
        automatic logic [31:0] total_time = distances[src] + (train_depart[i] << 16) + E;
        if (distances[src] != INF && total_time < next_distances[dst])
          next_distances[dst] = total_time;
      end
    end
  end
end

always_ff @(posedge clk) begin
  if (state_reg == INIT) begin
    distances[origin_idx] <= ZERO;
    for (int i=0; i<8; i=i+1) if (i != origin_idx) distances[i] <= INF;
    for (int i=0; i<16; i=i+1) begin
      if (i < num_trains) begin
        {train_src[i], train_dst[i], train_depart[i], train_time[i], 
         train_prob[i], train_delay[i]} = train_data_all[i*16+:37];
      end
    end
  end
end

endmodule